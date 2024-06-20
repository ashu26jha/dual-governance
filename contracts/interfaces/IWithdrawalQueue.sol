// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

struct WithdrawalRequestStatus {
    uint256 amountOfStETH;
    uint256 amountOfShares;
    address owner;
    uint256 timestamp;
    bool isFinalized;
    bool isClaimed;
}

interface IWithdrawalQueue {
    function MIN_STETH_WITHDRAWAL_AMOUNT() external view returns (uint256);
    function MAX_STETH_WITHDRAWAL_AMOUNT() external view returns (uint256);

    function claimWithdrawals(uint256[] calldata requestIds, uint256[] calldata hints) external;

    function getLastFinalizedRequestId() external view returns (uint256);

    function transferFrom(address from, address to, uint256 requestId) external;

    function getWithdrawalStatus(uint256[] calldata _requestIds)
        external
        view
        returns (WithdrawalRequestStatus[] memory statuses);

    function getLastRequestId() external view returns (uint256);

    /// @notice Returns amount of ether available for claim for each provided request id
    /// @param _requestIds array of request ids
    /// @param _hints checkpoint hints. can be found with `findCheckpointHints(_requestIds, 1, getLastCheckpointIndex())`
    /// @return claimableEthValues amount of claimable ether for each request, amount is equal to 0 if request
    ///  is not finalized or already claimed
    function getClaimableEther(
        uint256[] calldata _requestIds,
        uint256[] calldata _hints
    ) external view returns (uint256[] memory claimableEthValues);

    function balanceOf(address owner) external view returns (uint256);

    function requestWithdrawals(
        uint256[] calldata _amounts,
        address _owner
    ) external returns (uint256[] memory requestIds);

    function requestWithdrawalsWstETH(
        uint256[] calldata _amounts,
        address _owner
    ) external returns (uint256[] memory requestIds);
}
