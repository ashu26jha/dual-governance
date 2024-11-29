// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// ---
// Contracts
// ---
import {Timestamps} from "contracts/types/Timestamp.sol";
import {Duration} from "contracts/types/Duration.sol";

import {Executor} from "contracts/Executor.sol";
import {EmergencyProtectedTimelock} from "contracts/EmergencyProtectedTimelock.sol";

import {TimelockedGovernance} from "contracts/TimelockedGovernance.sol";

import {ResealManager} from "contracts/ResealManager.sol";
import {DualGovernance} from "contracts/DualGovernance.sol";
import {
    DualGovernanceConfig,
    IDualGovernanceConfigProvider,
    ImmutableDualGovernanceConfigProvider
} from "contracts/ImmutableDualGovernanceConfigProvider.sol";

import {TiebreakerCoreCommittee} from "contracts/committees/TiebreakerCoreCommittee.sol";
import {TiebreakerSubCommittee} from "contracts/committees/TiebreakerSubCommittee.sol";
import {ITimelock} from "contracts/interfaces/ITimelock.sol";
import {IResealManager} from "contracts/interfaces/IResealManager.sol";

import {DeployConfig, LidoContracts, getSubCommitteeData} from "./Config.sol";

struct DeployedContracts {
    Executor adminExecutor;
    EmergencyProtectedTimelock timelock;
    TimelockedGovernance emergencyGovernance;
    ResealManager resealManager;
    DualGovernance dualGovernance;
    TiebreakerCoreCommittee tiebreakerCoreCommittee;
    TiebreakerSubCommittee[] tiebreakerSubCommittees;
}

library DGContractsDeployment {
    function deployDualGovernanceSetup(
        DeployConfig memory dgDeployConfig,
        LidoContracts memory lidoAddresses,
        address deployer
    ) internal returns (DeployedContracts memory contracts) {
        contracts = deployAdminExecutorAndTimelock(dgDeployConfig, deployer);
        deployEmergencyProtectedTimelockContracts(lidoAddresses, dgDeployConfig, contracts);
        contracts.resealManager = deployResealManager(contracts.timelock);
        ImmutableDualGovernanceConfigProvider dualGovernanceConfigProvider =
            deployDualGovernanceConfigProvider(dgDeployConfig);
        DualGovernance dualGovernance = deployDualGovernance({
            configProvider: dualGovernanceConfigProvider,
            timelock: contracts.timelock,
            resealManager: contracts.resealManager,
            dgDeployConfig: dgDeployConfig,
            lidoAddresses: lidoAddresses
        });
        contracts.dualGovernance = dualGovernance;

        contracts.tiebreakerCoreCommittee = deployEmptyTiebreakerCoreCommittee({
            owner: deployer, // temporary set owner to deployer, to add sub committees manually
            dualGovernance: address(dualGovernance),
            executionDelay: dgDeployConfig.TIEBREAKER_EXECUTION_DELAY
        });

        contracts.tiebreakerSubCommittees = deployTiebreakerSubCommittees(
            address(contracts.adminExecutor), contracts.tiebreakerCoreCommittee, dgDeployConfig
        );

        contracts.tiebreakerCoreCommittee.transferOwnership(address(contracts.adminExecutor));

        // ---
        // Finalize Setup
        // ---
        configureDualGovernance(dgDeployConfig, lidoAddresses, contracts);

        finalizeEmergencyProtectedTimelockDeploy(
            contracts.adminExecutor, contracts.timelock, address(dualGovernance), dgDeployConfig
        );

        // ---
        // TODO: Use this in voting script
        // Grant Reseal Manager Roles
        // ---
        /* vm.startPrank(address(_lido.agent));
        _lido.withdrawalQueue.grantRole(
            0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d, address(resealManager)
        );
        _lido.withdrawalQueue.grantRole(
            0x2fc10cc8ae19568712f7a176fb4978616a610650813c9d05326c34abb62749c7, address(resealManager)
        );
        vm.stopPrank(); */
    }

    function deployAdminExecutorAndTimelock(
        DeployConfig memory dgDeployConfig,
        address deployer
    ) internal returns (DeployedContracts memory contracts) {
        Executor adminExecutor = deployExecutor(deployer);
        EmergencyProtectedTimelock timelock = deployEmergencyProtectedTimelock(address(adminExecutor), dgDeployConfig);

        contracts.adminExecutor = adminExecutor;
        contracts.timelock = timelock;
    }

    function deployEmergencyProtectedTimelockContracts(
        LidoContracts memory lidoAddresses,
        DeployConfig memory dgDeployConfig,
        DeployedContracts memory contracts
    ) internal {
        Executor adminExecutor = contracts.adminExecutor;
        EmergencyProtectedTimelock timelock = contracts.timelock;

        contracts.emergencyGovernance =
            deployTimelockedGovernance({governance: lidoAddresses.voting, timelock: timelock});

        adminExecutor.execute(
            address(timelock),
            0,
            abi.encodeCall(
                timelock.setEmergencyProtectionActivationCommittee, (dgDeployConfig.EMERGENCY_ACTIVATION_COMMITTEE)
            )
        );
        adminExecutor.execute(
            address(timelock),
            0,
            abi.encodeCall(
                timelock.setEmergencyProtectionExecutionCommittee, (dgDeployConfig.EMERGENCY_EXECUTION_COMMITTEE)
            )
        );

        adminExecutor.execute(
            address(timelock),
            0,
            abi.encodeCall(
                timelock.setEmergencyProtectionEndDate,
                (dgDeployConfig.EMERGENCY_PROTECTION_DURATION.addTo(Timestamps.now()))
            )
        );
        adminExecutor.execute(
            address(timelock),
            0,
            abi.encodeCall(timelock.setEmergencyModeDuration, (dgDeployConfig.EMERGENCY_MODE_DURATION))
        );

        adminExecutor.execute(
            address(timelock),
            0,
            abi.encodeCall(timelock.setEmergencyGovernance, (address(contracts.emergencyGovernance)))
        );
    }

    function deployExecutor(address owner) internal returns (Executor) {
        return new Executor(owner);
    }

    function deployEmergencyProtectedTimelock(
        address adminExecutor,
        DeployConfig memory dgDeployConfig
    ) internal returns (EmergencyProtectedTimelock) {
        return new EmergencyProtectedTimelock({
            adminExecutor: address(adminExecutor),
            sanityCheckParams: EmergencyProtectedTimelock.SanityCheckParams({
                minExecutionDelay: dgDeployConfig.MIN_EXECUTION_DELAY,
                maxAfterSubmitDelay: dgDeployConfig.MAX_AFTER_SUBMIT_DELAY,
                maxAfterScheduleDelay: dgDeployConfig.MAX_AFTER_SCHEDULE_DELAY,
                maxEmergencyModeDuration: dgDeployConfig.MAX_EMERGENCY_MODE_DURATION,
                maxEmergencyProtectionDuration: dgDeployConfig.MAX_EMERGENCY_PROTECTION_DURATION
            }),
            afterSubmitDelay: dgDeployConfig.AFTER_SUBMIT_DELAY,
            afterScheduleDelay: dgDeployConfig.AFTER_SCHEDULE_DELAY
        });
    }

    function deployTimelockedGovernance(
        address governance,
        ITimelock timelock
    ) internal returns (TimelockedGovernance) {
        return new TimelockedGovernance(governance, timelock);
    }

    function deployResealManager(ITimelock timelock) internal returns (ResealManager) {
        return new ResealManager(timelock);
    }

    function deployDualGovernanceConfigProvider(DeployConfig memory dgDeployConfig)
        internal
        returns (ImmutableDualGovernanceConfigProvider)
    {
        return new ImmutableDualGovernanceConfigProvider(
            DualGovernanceConfig.Context({
                firstSealRageQuitSupport: dgDeployConfig.FIRST_SEAL_RAGE_QUIT_SUPPORT,
                secondSealRageQuitSupport: dgDeployConfig.SECOND_SEAL_RAGE_QUIT_SUPPORT,
                //
                minAssetsLockDuration: dgDeployConfig.MIN_ASSETS_LOCK_DURATION,
                vetoSignallingMinDuration: dgDeployConfig.VETO_SIGNALLING_MIN_DURATION,
                vetoSignallingMaxDuration: dgDeployConfig.VETO_SIGNALLING_MAX_DURATION,
                //
                vetoSignallingMinActiveDuration: dgDeployConfig.VETO_SIGNALLING_MIN_ACTIVE_DURATION,
                vetoSignallingDeactivationMaxDuration: dgDeployConfig.VETO_SIGNALLING_DEACTIVATION_MAX_DURATION,
                vetoCooldownDuration: dgDeployConfig.VETO_COOLDOWN_DURATION,
                //
                rageQuitExtensionPeriodDuration: dgDeployConfig.RAGE_QUIT_EXTENSION_PERIOD_DURATION,
                rageQuitEthWithdrawalsMinDelay: dgDeployConfig.RAGE_QUIT_ETH_WITHDRAWALS_MIN_DELAY,
                rageQuitEthWithdrawalsMaxDelay: dgDeployConfig.RAGE_QUIT_ETH_WITHDRAWALS_MAX_DELAY,
                rageQuitEthWithdrawalsDelayGrowth: dgDeployConfig.RAGE_QUIT_ETH_WITHDRAWALS_DELAY_GROWTH
            })
        );
    }

    function deployDualGovernance(
        IDualGovernanceConfigProvider configProvider,
        ITimelock timelock,
        IResealManager resealManager,
        DeployConfig memory dgDeployConfig,
        LidoContracts memory lidoAddresses
    ) internal returns (DualGovernance) {
        return new DualGovernance({
            dependencies: DualGovernance.ExternalDependencies({
                stETH: lidoAddresses.stETH,
                wstETH: lidoAddresses.wstETH,
                withdrawalQueue: lidoAddresses.withdrawalQueue,
                timelock: timelock,
                resealManager: resealManager,
                configProvider: configProvider
            }),
            sanityCheckParams: DualGovernance.SanityCheckParams({
                minWithdrawalsBatchSize: dgDeployConfig.MIN_WITHDRAWALS_BATCH_SIZE,
                minTiebreakerActivationTimeout: dgDeployConfig.MIN_TIEBREAKER_ACTIVATION_TIMEOUT,
                maxTiebreakerActivationTimeout: dgDeployConfig.MAX_TIEBREAKER_ACTIVATION_TIMEOUT,
                maxSealableWithdrawalBlockersCount: dgDeployConfig.MAX_SEALABLE_WITHDRAWAL_BLOCKERS_COUNT
            })
        });
    }

    function deployEmptyTiebreakerCoreCommittee(
        address owner,
        address dualGovernance,
        Duration executionDelay
    ) internal returns (TiebreakerCoreCommittee) {
        return new TiebreakerCoreCommittee({owner: owner, dualGovernance: dualGovernance, timelock: executionDelay});
    }

    function deployTiebreakerSubCommittees(
        address owner,
        TiebreakerCoreCommittee tiebreakerCoreCommittee,
        DeployConfig memory dgDeployConfig
    ) internal returns (TiebreakerSubCommittee[] memory tiebreakerSubCommittees) {
        tiebreakerSubCommittees = new TiebreakerSubCommittee[](dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_COUNT);
        address[] memory coreCommitteeMembers = new address[](dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_COUNT);

        for (uint256 i = 0; i < dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_COUNT; ++i) {
            (uint256 quorum, address[] memory members) = getSubCommitteeData(i, dgDeployConfig);

            tiebreakerSubCommittees[i] = deployTiebreakerSubCommittee({
                owner: owner,
                quorum: quorum,
                members: members,
                tiebreakerCoreCommittee: address(tiebreakerCoreCommittee)
            });
            coreCommitteeMembers[i] = address(tiebreakerSubCommittees[i]);
        }

        tiebreakerCoreCommittee.addMembers(coreCommitteeMembers, dgDeployConfig.TIEBREAKER_CORE_QUORUM);

        return tiebreakerSubCommittees;
    }

    function deployTiebreakerSubCommittee(
        address owner,
        uint256 quorum,
        address[] memory members,
        address tiebreakerCoreCommittee
    ) internal returns (TiebreakerSubCommittee) {
        return new TiebreakerSubCommittee({
            owner: owner,
            executionQuorum: quorum,
            committeeMembers: members,
            tiebreakerCoreCommittee: tiebreakerCoreCommittee
        });
    }

    function configureDualGovernance(
        DeployConfig memory dgDeployConfig,
        LidoContracts memory lidoAddresses,
        DeployedContracts memory contracts
    ) internal {
        contracts.adminExecutor.execute(
            address(contracts.dualGovernance),
            0,
            abi.encodeCall(
                contracts.dualGovernance.registerProposer, (lidoAddresses.voting, address(contracts.adminExecutor))
            )
        );
        contracts.adminExecutor.execute(
            address(contracts.dualGovernance),
            0,
            abi.encodeCall(
                contracts.dualGovernance.setTiebreakerActivationTimeout, dgDeployConfig.TIEBREAKER_ACTIVATION_TIMEOUT
            )
        );
        contracts.adminExecutor.execute(
            address(contracts.dualGovernance),
            0,
            abi.encodeCall(contracts.dualGovernance.setTiebreakerCommittee, address(contracts.tiebreakerCoreCommittee))
        );
        contracts.adminExecutor.execute(
            address(contracts.dualGovernance),
            0,
            abi.encodeCall(
                contracts.dualGovernance.addTiebreakerSealableWithdrawalBlocker, address(lidoAddresses.withdrawalQueue)
            )
        );
        contracts.adminExecutor.execute(
            address(contracts.dualGovernance),
            0,
            abi.encodeCall(contracts.dualGovernance.setResealCommittee, dgDeployConfig.RESEAL_COMMITTEE)
        );
    }

    function finalizeEmergencyProtectedTimelockDeploy(
        Executor adminExecutor,
        EmergencyProtectedTimelock timelock,
        address dualGovernance,
        DeployConfig memory dgDeployConfig
    ) internal {
        adminExecutor.execute(address(timelock), 0, abi.encodeCall(timelock.setGovernance, (dualGovernance)));
        adminExecutor.transferOwnership(address(timelock));
    }
}
