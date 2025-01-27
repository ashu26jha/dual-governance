// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Durations} from "contracts/types/Duration.sol";

import {Ownable, Executor} from "contracts/Executor.sol";
import {Proposers} from "contracts/libraries/Proposers.sol";

import {ExternalCall, ScenarioTestBlueprint, ExternalCallHelpers} from "../utils/scenario-test-blueprint.sol";

interface ISomeContract {
    function someMethod(uint256 someParameter) external;
}

contract ExecutorOwnershipTransfer is ScenarioTestBlueprint {
    address private immutable _NEW_REGULAR_PROPOSER = makeAddr("NEW_REGULAR_PROPOSER");

    Executor private _oldAdminExecutor;
    Executor private _newAdminExecutor;

    function setUp() external {
        _deployDualGovernanceSetup({isEmergencyProtectionEnabled: false});
        _newAdminExecutor = new Executor({owner: address(this)});

        _oldAdminExecutor = Executor(payable(_contracts.timelock.getAdminExecutor()));
        _newAdminExecutor.transferOwnership(address(_contracts.timelock));
    }

    function testFork_ExecutorOwnershipTransfer_HappyPath() external {
        _step("1. DAO creates proposal to add new proposer and change the admin executor");
        uint256 shuffleExecutorsProposalId;
        {
            ExternalCall[] memory executorsShuffleCalls = ExternalCallHelpers.create(
                [
                    // 1. Register new proposer and assign it to the old admin executor
                    ExternalCall({
                        value: 0,
                        target: address(_contracts.dualGovernance),
                        payload: abi.encodeCall(
                            _contracts.dualGovernance.registerProposer, (_NEW_REGULAR_PROPOSER, address(_oldAdminExecutor))
                        )
                    }),
                    // 2. Assign previous proposer (Aragon Voting) to the new executor
                    ExternalCall({
                        value: 0,
                        target: address(_contracts.dualGovernance),
                        payload: abi.encodeCall(
                            _contracts.dualGovernance.setProposerExecutor, (address(_lido.voting), address(_newAdminExecutor))
                        )
                    }),
                    // 3. Replace the admin executor of the Timelock contract
                    ExternalCall({
                        value: 0,
                        target: address(_contracts.timelock),
                        payload: abi.encodeCall(_contracts.timelock.setAdminExecutor, (address(_newAdminExecutor)))
                    })
                ]
            );
            shuffleExecutorsProposalId =
                _submitProposalViaDualGovernance("Register new proposer and swap executors", executorsShuffleCalls);
        }

        _step("2. Proposal is scheduled and executed");
        {
            _assertProposalSubmitted(shuffleExecutorsProposalId);
            _waitAfterSubmitDelayPassed();

            _scheduleProposalViaDualGovernance(shuffleExecutorsProposalId);
            _assertProposalScheduled(shuffleExecutorsProposalId);
            _waitAfterScheduleDelayPassed();

            _executeProposal(shuffleExecutorsProposalId);
        }
        _step("3. The proposers and executors were set up correctly");
        {
            assertEq(_contracts.timelock.getAdminExecutor(), address(_newAdminExecutor));

            Proposers.Proposer[] memory proposers = _contracts.dualGovernance.getProposers();

            assertEq(proposers.length, 2);

            assertEq(proposers[0].account, address(_lido.voting));
            assertEq(proposers[0].executor, address(_newAdminExecutor));

            assertEq(proposers[1].account, _NEW_REGULAR_PROPOSER);
            assertEq(proposers[1].executor, address(_oldAdminExecutor));
        }

        _step("4. New admin proposer can manage Dual Governance contracts");
        {
            ExternalCall[] memory dgManageOperations = ExternalCallHelpers.create(
                [
                    ExternalCall({
                        value: 0,
                        target: address(_contracts.dualGovernance),
                        payload: abi.encodeCall(_contracts.dualGovernance.unregisterProposer, (_NEW_REGULAR_PROPOSER))
                    }),
                    ExternalCall({
                        value: 0,
                        target: address(_contracts.timelock),
                        payload: abi.encodeCall(
                            _contracts.timelock.transferExecutorOwnership,
                            (address(_oldAdminExecutor), address(_newAdminExecutor))
                        )
                    }),
                    ExternalCall({
                        value: 0,
                        target: address(_oldAdminExecutor),
                        payload: abi.encodeCall(
                            _oldAdminExecutor.execute, (address(_targetMock), 0, abi.encodeCall(ISomeContract.someMethod, (42)))
                        )
                    }),
                    ExternalCall({
                        value: 0,
                        target: address(_oldAdminExecutor),
                        payload: abi.encodeCall(_oldAdminExecutor.transferOwnership, (address(_contracts.timelock)))
                    }),
                    ExternalCall({
                        value: 0,
                        target: address(_contracts.timelock),
                        payload: abi.encodeCall(_contracts.timelock.setAfterSubmitDelay, (Durations.from(5 days)))
                    }),
                    ExternalCall({
                        value: 0,
                        target: address(_contracts.timelock),
                        payload: abi.encodeCall(_contracts.timelock.setAfterScheduleDelay, (Durations.ZERO))
                    })
                ]
            );

            uint256 proposalId =
                _submitProposalViaDualGovernance("Manage Dual Governance parameters", dgManageOperations);

            _assertProposalSubmitted(proposalId);
            _waitAfterSubmitDelayPassed();

            _scheduleProposalViaDualGovernance(proposalId);
            _assertProposalScheduled(proposalId);
            _waitAfterScheduleDelayPassed();

            _executeProposal(proposalId);

            Proposers.Proposer[] memory proposers = _contracts.dualGovernance.getProposers();

            assertEq(proposers.length, 1);
            assertEq(proposers[0].account, address(_lido.voting));
            assertEq(proposers[0].executor, address(_newAdminExecutor));

            assertEq(_contracts.timelock.getAfterScheduleDelay(), Durations.ZERO);

            assertEq(_oldAdminExecutor.owner(), address(_contracts.timelock));
        }
    }
}
