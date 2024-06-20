// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IExecutor, ExecutorCall} from "../interfaces/IExecutor.sol";

import {TimeUtils} from "../utils/time.sol";

enum Status {
    NotExist,
    Submitted,
    Scheduled,
    Executed,
    Canceled
}

struct Proposal {
    uint256 id;
    Status status;
    address executor;
    uint256 submittedAt;
    uint256 scheduledAt;
    uint256 executedAt;
    ExecutorCall[] calls;
}

library Proposals {
    struct ProposalPacked {
        address executor;
        uint40 submittedAt;
        uint40 scheduledAt;
        uint40 executedAt;
        ExecutorCall[] calls;
    }

    struct State {
        // any proposals with ids less or equal to the given one cannot be executed
        uint256 lastCanceledProposalId;
        ProposalPacked[] proposals;
    }

    error EmptyCalls();
    error ProposalCanceled(uint256 proposalId);
    error ProposalNotFound(uint256 proposalId);
    error ProposalNotScheduled(uint256 proposalId);
    error ProposalNotSubmitted(uint256 proposalId);
    error AfterSubmitDelayNotPassed(uint256 proposalId);
    error AfterScheduleDelayNotPassed(uint256 proposalId);

    event ProposalScheduled(uint256 indexed id);
    event ProposalSubmitted(uint256 indexed id, address indexed executor, ExecutorCall[] calls);
    event ProposalExecuted(uint256 indexed id, bytes[] callResults);
    event ProposalsCanceledTill(uint256 proposalId);

    // The id of the first proposal
    uint256 private constant PROPOSAL_ID_OFFSET = 1;

    function submit(
        State storage self,
        address executor,
        ExecutorCall[] calldata calls
    ) internal returns (uint256 newProposalId) {
        if (calls.length == 0) {
            revert EmptyCalls();
        }

        uint256 newProposalIndex = self.proposals.length;

        self.proposals.push();
        ProposalPacked storage newProposal = self.proposals[newProposalIndex];
        newProposal.executor = executor;

        newProposal.executedAt = 0;
        newProposal.submittedAt = TimeUtils.timestamp();

        // copying of arrays of custom types from calldata to storage has not been supported by the
        // Solidity compiler yet, so insert item by item
        for (uint256 i = 0; i < calls.length; ++i) {
            newProposal.calls.push(calls[i]);
        }

        newProposalId = newProposalIndex + PROPOSAL_ID_OFFSET;
        emit ProposalSubmitted(newProposalId, executor, calls);
    }

    function schedule(
        State storage self,
        uint256 proposalId,
        uint256 afterSubmitDelay
    ) internal returns (uint256 submittedAt) {
        _checkProposalSubmitted(self, proposalId);
        _checkAfterSubmitDelayPassed(self, proposalId, afterSubmitDelay);
        ProposalPacked storage proposal = _packed(self, proposalId);

        submittedAt = proposal.submittedAt;
        proposal.scheduledAt = TimeUtils.timestamp();

        emit ProposalScheduled(proposalId);
    }

    function execute(State storage self, uint256 proposalId, uint256 afterScheduleDelay) internal {
        _checkProposalScheduled(self, proposalId);
        _checkAfterScheduleDelayPassed(self, proposalId, afterScheduleDelay);
        _executeProposal(self, proposalId);
    }

    function cancelAll(State storage self) internal {
        uint256 lastProposalId = self.proposals.length;
        self.lastCanceledProposalId = lastProposalId;
        emit ProposalsCanceledTill(lastProposalId);
    }

    function get(State storage self, uint256 proposalId) internal view returns (Proposal memory proposal) {
        _checkProposalExists(self, proposalId);
        ProposalPacked storage packed = _packed(self, proposalId);

        proposal.id = proposalId;
        proposal.status = _getProposalStatus(self, proposalId);
        proposal.executor = packed.executor;
        proposal.submittedAt = packed.submittedAt;
        proposal.executedAt = packed.executedAt;
        proposal.calls = packed.calls;
    }

    function count(State storage self) internal view returns (uint256 count_) {
        count_ = self.proposals.length;
    }

    function canExecute(
        State storage self,
        uint256 proposalId,
        uint256 afterScheduleDelay
    ) internal view returns (bool) {
        return _getProposalStatus(self, proposalId) == Status.Scheduled
            && block.timestamp >= _packed(self, proposalId).scheduledAt + afterScheduleDelay;
    }

    function canSchedule(
        State storage self,
        uint256 proposalId,
        uint256 afterSubmitDelay
    ) internal view returns (bool) {
        return _getProposalStatus(self, proposalId) == Status.Submitted
            && block.timestamp >= _packed(self, proposalId).submittedAt + afterSubmitDelay;
    }

    function _executeProposal(State storage self, uint256 proposalId) private returns (bytes[] memory results) {
        ProposalPacked storage packed = _packed(self, proposalId);
        packed.executedAt = TimeUtils.timestamp();

        ExecutorCall[] memory calls = packed.calls;
        uint256 callsCount = calls.length;

        assert(callsCount > 0);

        address executor = packed.executor;
        results = new bytes[](callsCount);
        for (uint256 i = 0; i < callsCount; ++i) {
            results[i] = IExecutor(payable(executor)).execute(calls[i].target, calls[i].value, calls[i].payload);
        }
        emit ProposalExecuted(proposalId, results);
    }

    function _packed(State storage self, uint256 proposalId) private view returns (ProposalPacked storage packed) {
        packed = self.proposals[proposalId - PROPOSAL_ID_OFFSET];
    }

    function _checkProposalExists(State storage self, uint256 proposalId) private view {
        if (proposalId < PROPOSAL_ID_OFFSET || proposalId > self.proposals.length) {
            revert ProposalNotFound(proposalId);
        }
    }

    function _checkProposalSubmitted(State storage self, uint256 proposalId) private view {
        Status status = _getProposalStatus(self, proposalId);
        if (status != Status.Submitted) {
            revert ProposalNotSubmitted(proposalId);
        }
    }

    function _checkProposalScheduled(State storage self, uint256 proposalId) private view {
        Status status = _getProposalStatus(self, proposalId);
        if (status != Status.Scheduled) {
            revert ProposalNotScheduled(proposalId);
        }
    }

    function _checkAfterSubmitDelayPassed(
        State storage self,
        uint256 proposalId,
        uint256 afterSubmitDelay
    ) private view {
        if (block.timestamp < _packed(self, proposalId).submittedAt + afterSubmitDelay) {
            revert AfterSubmitDelayNotPassed(proposalId);
        }
    }

    function _checkAfterScheduleDelayPassed(
        State storage self,
        uint256 proposalId,
        uint256 afterScheduleDelay
    ) private view {
        if (block.timestamp < _packed(self, proposalId).scheduledAt + afterScheduleDelay) {
            revert AfterScheduleDelayNotPassed(proposalId);
        }
    }

    function _getProposalStatus(State storage self, uint256 proposalId) private view returns (Status) {
        if (proposalId < PROPOSAL_ID_OFFSET || proposalId > self.proposals.length) return Status.NotExist;

        ProposalPacked storage packed = _packed(self, proposalId);

        if (packed.executedAt != 0) return Status.Executed;
        if (proposalId <= self.lastCanceledProposalId) return Status.Canceled;
        if (packed.scheduledAt != 0) return Status.Scheduled;
        if (packed.submittedAt != 0) return Status.Submitted;
        assert(false);
    }
}
