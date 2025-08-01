// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IOracleReportSanityChecker {
    /// @notice The set of restrictions used in the sanity checks of the oracle report
    /// @dev struct is loaded from the storage and stored in memory during the tx running
    struct LimitsList {
        /// @notice The max possible number of validators that might be reported as `exited`
        ///     per single day, depends on the Consensus Layer churn limit
        /// @dev Must fit into uint16 (<= 65_535)
        uint256 exitedValidatorsPerDayLimit;
        /// @notice The max possible number of validators that might be reported as `appeared`
        ///     per single day, limited by the max daily deposits via DepositSecurityModule in practice
        ///     isn't limited by a consensus layer (because `appeared` includes `pending`, i.e., not `activated` yet)
        /// @dev Must fit into uint16 (<= 65_535)
        uint256 appearedValidatorsPerDayLimit;
        /// @notice The max annual increase of the total validators' balances on the Consensus Layer
        ///     since the previous oracle report
        /// @dev Represented in the Basis Points (100% == 10_000)
        uint256 annualBalanceIncreaseBPLimit;
        /// @notice The max deviation of the provided `simulatedShareRate`
        ///     and the actual one within the currently processing oracle report
        /// @dev Represented in the Basis Points (100% == 10_000)
        uint256 simulatedShareRateDeviationBPLimit;
        /// @notice The max number of exit requests allowed in report to ValidatorsExitBusOracle
        uint256 maxValidatorExitRequestsPerReport;
        /// @notice The max number of data list items reported to accounting oracle in extra data per single transaction
        /// @dev Must fit into uint16 (<= 65_535)
        uint256 maxItemsPerExtraDataTransaction;
        /// @notice The max number of node operators reported per extra data list item
        /// @dev Must fit into uint16 (<= 65_535)
        uint256 maxNodeOperatorsPerExtraDataItem;
        /// @notice The min time required to be passed from the creation of the request to be
        ///     finalized till the time of the oracle report
        uint256 requestTimestampMargin;
        /// @notice The positive token rebase allowed per single LidoOracle report
        /// @dev uses 1e9 precision, e.g.: 1e6 - 0.1%; 1e9 - 100%, see `setMaxPositiveTokenRebase()`
        uint256 maxPositiveTokenRebase;
        /// @notice Initial slashing amount per one validator to calculate initial slashing of the validators' balances on the Consensus Layer
        /// @dev Represented in the PWei (1^15 Wei). Must fit into uint16 (<= 65_535)
        uint256 initialSlashingAmountPWei;
        /// @notice Inactivity penalties amount per one validator to calculate penalties of the validators' balances on the Consensus Layer
        /// @dev Represented in the PWei (1^15 Wei). Must fit into uint16 (<= 65_535)
        uint256 inactivityPenaltiesAmountPWei;
        /// @notice The maximum percent on how Second Opinion Oracle reported value could be greater
        ///     than reported by the AccountingOracle. There is an assumption that second opinion oracle CL balance
        ///     can be greater as calculated for the withdrawal credentials.
        /// @dev Represented in the Basis Points (100% == 10_000)
        uint256 clBalanceOraclesErrorUpperBPLimit;
    }

    function grantRole(bytes32 role, address account) external;

    function getOracleReportLimits() external view returns (LimitsList memory);

    function setAnnualBalanceIncreaseBPLimit(uint256 _annualBalanceIncreaseBPLimit) external;
    function setRequestTimestampMargin(uint256 _requestTimestampMargin) external;

    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    function REQUEST_TIMESTAMP_MARGIN_MANAGER_ROLE() external pure returns (bytes32);
    function ANNUAL_BALANCE_INCREASE_LIMIT_MANAGER_ROLE() external pure returns (bytes32);
}
