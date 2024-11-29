// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/* solhint-disable var-name-mixedcase */

import {IStETH} from "contracts/interfaces/IStETH.sol";
import {IWstETH} from "contracts/interfaces/IWstETH.sol";
import {IWithdrawalQueue} from "contracts/interfaces/IWithdrawalQueue.sol";
import {Duration} from "contracts/types/Duration.sol";
import {PercentD16} from "contracts/types/PercentD16.sol";

// TODO: choose better value for MIN_EXECUTION_DELAY
uint256 constant DEFAULT_MIN_EXECUTION_DELAY = 0 seconds;
uint256 constant DEFAULT_AFTER_SUBMIT_DELAY = 3 days;
uint256 constant DEFAULT_MAX_AFTER_SUBMIT_DELAY = 45 days;
uint256 constant DEFAULT_AFTER_SCHEDULE_DELAY = 3 days;
uint256 constant DEFAULT_MAX_AFTER_SCHEDULE_DELAY = 45 days;
uint256 constant DEFAULT_EMERGENCY_MODE_DURATION = 180 days;
uint256 constant DEFAULT_MAX_EMERGENCY_MODE_DURATION = 365 days;
uint256 constant DEFAULT_EMERGENCY_PROTECTION_DURATION = 90 days;
uint256 constant DEFAULT_MAX_EMERGENCY_PROTECTION_DURATION = 365 days;
uint256 constant DEFAULT_TIEBREAKER_CORE_QUORUM = 1;
uint256 constant DEFAULT_TIEBREAKER_EXECUTION_DELAY = 30 days;
uint256 constant DEFAULT_TIEBREAKER_SUB_COMMITTEES_COUNT = 2;
uint256 constant DEFAULT_MIN_WITHDRAWALS_BATCH_SIZE = 4;
uint256 constant DEFAULT_MIN_TIEBREAKER_ACTIVATION_TIMEOUT = 90 days;
uint256 constant DEFAULT_TIEBREAKER_ACTIVATION_TIMEOUT = 365 days;
uint256 constant DEFAULT_MAX_TIEBREAKER_ACTIVATION_TIMEOUT = 730 days;
uint256 constant DEFAULT_MAX_SEALABLE_WITHDRAWAL_BLOCKERS_COUNT = 255;

uint256 constant DEFAULT_FIRST_SEAL_RAGE_QUIT_SUPPORT = 3_00; // 3%
uint256 constant DEFAULT_SECOND_SEAL_RAGE_QUIT_SUPPORT = 15_00; // 15%
uint256 constant DEFAULT_MIN_ASSETS_LOCK_DURATION = 5 hours;
uint256 constant DEFAULT_VETO_SIGNALLING_MIN_DURATION = 3 days;
uint256 constant DEFAULT_VETO_SIGNALLING_MAX_DURATION = 30 days;
uint256 constant DEFAULT_VETO_SIGNALLING_MIN_ACTIVE_DURATION = 5 hours;
uint256 constant DEFAULT_VETO_SIGNALLING_DEACTIVATION_MAX_DURATION = 5 days;
uint256 constant DEFAULT_VETO_COOLDOWN_DURATION = 4 days;
uint256 constant DEFAULT_RAGE_QUIT_EXTENSION_PERIOD_DURATION = 7 days;
uint256 constant DEFAULT_RAGE_QUIT_ETH_WITHDRAWALS_MIN_DELAY = 30 days;
uint256 constant DEFAULT_RAGE_QUIT_ETH_WITHDRAWALS_MAX_DELAY = 180 days;
uint256 constant DEFAULT_RAGE_QUIT_ETH_WITHDRAWALS_DELAY_GROWTH = 15 days;

bytes32 constant CHAIN_NAME_MAINNET_HASH = keccak256(bytes("mainnet"));
bytes32 constant CHAIN_NAME_HOLESKY_HASH = keccak256(bytes("holesky"));
bytes32 constant CHAIN_NAME_HOLESKY_MOCKS_HASH = keccak256(bytes("holesky-mocks"));

struct DeployConfig {
    Duration MIN_EXECUTION_DELAY;
    Duration AFTER_SUBMIT_DELAY;
    Duration MAX_AFTER_SUBMIT_DELAY;
    Duration AFTER_SCHEDULE_DELAY;
    Duration MAX_AFTER_SCHEDULE_DELAY;
    Duration EMERGENCY_MODE_DURATION;
    Duration MAX_EMERGENCY_MODE_DURATION;
    Duration EMERGENCY_PROTECTION_DURATION;
    Duration MAX_EMERGENCY_PROTECTION_DURATION;
    address EMERGENCY_ACTIVATION_COMMITTEE;
    address EMERGENCY_EXECUTION_COMMITTEE;
    uint256 TIEBREAKER_CORE_QUORUM;
    Duration TIEBREAKER_EXECUTION_DELAY;
    uint256 TIEBREAKER_SUB_COMMITTEES_COUNT;
    address[] TIEBREAKER_SUB_COMMITTEE_1_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_2_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_3_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_4_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_5_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_6_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_7_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_8_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_9_MEMBERS;
    address[] TIEBREAKER_SUB_COMMITTEE_10_MEMBERS;
    uint256[] TIEBREAKER_SUB_COMMITTEES_QUORUMS;
    address RESEAL_COMMITTEE;
    uint256 MIN_WITHDRAWALS_BATCH_SIZE;
    Duration MIN_TIEBREAKER_ACTIVATION_TIMEOUT;
    Duration TIEBREAKER_ACTIVATION_TIMEOUT;
    Duration MAX_TIEBREAKER_ACTIVATION_TIMEOUT;
    uint256 MAX_SEALABLE_WITHDRAWAL_BLOCKERS_COUNT;
    PercentD16 FIRST_SEAL_RAGE_QUIT_SUPPORT;
    PercentD16 SECOND_SEAL_RAGE_QUIT_SUPPORT;
    Duration MIN_ASSETS_LOCK_DURATION;
    Duration VETO_SIGNALLING_MIN_DURATION;
    Duration VETO_SIGNALLING_MAX_DURATION;
    Duration VETO_SIGNALLING_MIN_ACTIVE_DURATION;
    Duration VETO_SIGNALLING_DEACTIVATION_MAX_DURATION;
    Duration VETO_COOLDOWN_DURATION;
    Duration RAGE_QUIT_EXTENSION_PERIOD_DURATION;
    Duration RAGE_QUIT_ETH_WITHDRAWALS_MIN_DELAY;
    Duration RAGE_QUIT_ETH_WITHDRAWALS_MAX_DELAY;
    Duration RAGE_QUIT_ETH_WITHDRAWALS_DELAY_GROWTH;
}

struct LidoContracts {
    uint256 chainId;
    IStETH stETH;
    IWstETH wstETH;
    IWithdrawalQueue withdrawalQueue;
    address voting;
}

function getSubCommitteeData(
    uint256 index,
    DeployConfig memory dgDeployConfig
) pure returns (uint256 quorum, address[] memory members) {
    assert(index <= 10);

    if (index == 0) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[0];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_1_MEMBERS;
    }

    if (index == 1) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[1];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_2_MEMBERS;
    }

    if (index == 2) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[2];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_3_MEMBERS;
    }

    if (index == 3) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[3];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_4_MEMBERS;
    }
    if (index == 4) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[4];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_5_MEMBERS;
    }
    if (index == 5) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[5];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_6_MEMBERS;
    }
    if (index == 6) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[6];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_7_MEMBERS;
    }
    if (index == 7) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[7];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_8_MEMBERS;
    }
    if (index == 8) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[8];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_9_MEMBERS;
    }
    if (index == 9) {
        quorum = dgDeployConfig.TIEBREAKER_SUB_COMMITTEES_QUORUMS[9];
        members = dgDeployConfig.TIEBREAKER_SUB_COMMITTEE_10_MEMBERS;
    }
}
