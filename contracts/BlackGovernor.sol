// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IBlackHoleVotes} from "./interfaces/IBlackHoleVotes.sol";
import {L2Governor, L2GovernorCountingSimple, L2GovernorVotes, L2GovernorVotesQuorumFraction} from "./governance/Governor.sol";

contract BlackGovernor is
    L2Governor,
    L2GovernorCountingSimple,
    L2GovernorVotes,
    L2GovernorVotesQuorumFraction
{
    address public team;
    uint256 public constant MAX_PROPOSAL_NUMERATOR = 100; // max 10%
    uint256 public constant PROPOSAL_DENOMINATOR = 1000;
    uint256 public proposalNumerator = 2; // start at 0.02%

    constructor(
        IBlackHoleVotes _ve,
        address _minter
    )
        L2Governor("Black Governor", _minter)
        L2GovernorVotes(_ve)
        L2GovernorVotesQuorumFraction(4) // 4%
    {
        team = msg.sender;
    }

    function votingDelay() public pure override(IGovernor) returns (uint256) {
        return 2 minutes; // 1 block
    }

    function votingPeriod() public pure override(IGovernor) returns (uint256) {
        return 30 minutes;
    }

    function setTeam(address newTeam) external {
        require(msg.sender == team, "not team");
        team = newTeam;
    }

    //TODO:: Abhijeet remove this function as used for testing and variable in Governor.sol
    function epochStarts() external view returns (bytes32){
        return epochStart;
    }

    //TODO:: Abhijeet remove this function as used for testing and variable in Governor.sol
    function getProposalId() external view returns (uint256){
        return proposalIdMain;
    }

    function setProposalNumerator(uint256 numerator) external {
        require(msg.sender == team, "not team");
        require(numerator <= MAX_PROPOSAL_NUMERATOR, "numerator too high");
        proposalNumerator = numerator;
    }

    function proposalThreshold()
        public
        view
        override(L2Governor)
        returns (uint256)
    {
        return
            (token.getPastTotalSupply(block.timestamp) * proposalNumerator) /
            PROPOSAL_DENOMINATOR;
    }

    function clock() public view override returns (uint48) {}

    function CLOCK_MODE() public view override returns (string memory) {}

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 epochTimeHash
    ) public virtual override returns (uint256 proposalId) {
        address proposer = _msgSender();
        uint256 _proposalId = hashProposal(
            targets,
            values,
            calldatas,
            epochTimeHash
        );
        require(
            state(proposalId) == ProposalState.Pending,
            "Governor: too late to cancel"
        );
        require(
            proposer == _proposals[_proposalId].proposer,
            "Governor: only proposer can cancel"
        );
        return _cancel(targets, values, calldatas, epochTimeHash);
    }

    function quorum(uint256 blockTimestamp) public view override (L2GovernorVotesQuorumFraction, IGovernor) returns (uint256) {
        return (token.getsmNFTPastTotalSupply() * quorumNumerator()) / quorumDenominator();
    }
}
