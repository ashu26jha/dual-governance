// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IDualGovernanceConfigProvider} from "./IDualGovernanceConfigProvider.sol";
import {IGovernance} from "./IGovernance.sol";
import {IEscrow} from "./IEscrow.sol";
import {IResealManager} from "./IResealManager.sol";
import {ITiebreaker} from "./ITiebreaker.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Duration} from "../types/Duration.sol";
import {State} from "../libraries/DualGovernanceStateMachine.sol";
import {Proposers} from "../libraries/Proposers.sol";

interface IDualGovernance is IGovernance, ITiebreaker {
    struct StateDetails {
        State effectiveState;
        State persistedState;
        Timestamp persistedStateEnteredAt;
        Timestamp vetoSignallingActivatedAt;
        Timestamp vetoSignallingReactivationTime;
        Timestamp normalOrVetoCooldownExitedAt;
        uint256 rageQuitRound;
        Duration vetoSignallingDuration;
    }

    function MIN_TIEBREAKER_ACTIVATION_TIMEOUT() external view returns (Duration);
    function MAX_TIEBREAKER_ACTIVATION_TIMEOUT() external view returns (Duration);
    function MAX_SEALABLE_WITHDRAWAL_BLOCKERS_COUNT() external view returns (uint256);
    function ESCROW_MASTER_COPY() external view returns (IEscrow);

    function canSubmitProposal() external view returns (bool);
    function canCancelAllPendingProposals() external view returns (bool);
    function activateNextState() external;
    function setConfigProvider(IDualGovernanceConfigProvider newConfigProvider) external;
    function getConfigProvider() external view returns (IDualGovernanceConfigProvider);
    function getVetoSignallingEscrow() external view returns (address);
    function getRageQuitEscrow() external view returns (address);
    function getPersistedState() external view returns (State persistedState);
    function getEffectiveState() external view returns (State effectiveState);
    function getStateDetails() external view returns (StateDetails memory stateDetails);

    function registerProposer(address proposer, address executor) external;
    function unregisterProposer(address proposer) external;
    function isProposer(address account) external view returns (bool);
    function getProposer(address account) external view returns (Proposers.Proposer memory proposer);
    function getProposers() external view returns (Proposers.Proposer[] memory proposers);
    function isExecutor(address account) external view returns (bool);

    function resealSealable(address sealable) external;
    function setResealCommittee(address resealCommittee) external;
    function setResealManager(address resealManager) external;
    function getResealManager() external view returns (IResealManager);
    function getResealCommittee() external view returns (address);
}
