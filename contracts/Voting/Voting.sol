// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


// NOTE: We should orient ourselves along the lines of the dOrg Governance model
// eg. multisig by top7 rep holders
// implement relative majority voting
// implement delegation

contract Voting {

    enum Type {absoluteThreshold, permilleThreshold, deadline, deadlineAbsoluteThreshold, deadlinePermilleThreshold}
    enum Status {inactive, active, passed, failed}

    struct Info {
        Type votingType;
        Status votingStatus;
        uint40 deadline;
        uint120 threshold;
        uint256 votesFor;
        uint256 votesAgainst;
        uint120 totalAmount;
        address nominee;
    }

    uint256 MILLE = 1000;
    mapping(address=>mapping(uint256=>Info)) public voteInfo;
    mapping(address=>uint256) polls;
    mapping(address=>mapping(uint256=>mapping(address=>uint256))) public votes;
    mapping(address=>mapping(uint256=>mapping(address=>bool))) public alreadyVoted;

    function start(uint8 _votingType, uint40 _deadline, uint120 _threshold, uint120 _totalAmount) external returns(uint256) {
        polls[msg.sender] += 1;
        voteInfo[msg.sender][polls[msg.sender]] = Info({
            votingType: Type(_votingType),
            votingStatus: Status.active,
            deadline: _deadline,
            threshold: _threshold,
            votesFor: 0,
            votesAgainst: 0,
            totalAmount: _totalAmount,
            nominee: address(0x0)});
        return polls[msg.sender];
    }

    function _vote(uint256 poll_id, address votedOn, uint256 amount) 
    internal 
    {
        votes[msg.sender][poll_id][votedOn] += amount;
    }

    function vote(uint256 poll_id, address votedBy, address votedOn, uint256 amount)
    public 
    hasAlreadyVoted(poll_id, votedBy)
    {
        _vote(poll_id, votedOn, amount);
        alreadyVoted[msg.sender][poll_id][votedBy] = true;
    }

    function safeVote(uint256 poll_id, address votedBy, address votedOn, uint128 amount) 
    public 
    hasAlreadyVoted(poll_id, votedBy)
    withStatusHandling(poll_id, votedBy, votedOn)
    {
        _vote(poll_id, votedOn, amount);
        alreadyVoted[msg.sender][poll_id][votedBy] = true;
    }

    function safeVoteReturnStatus(uint256 poll_id, address votedBy, address votedOn, uint128 amount)
    external
    returns(uint8)
    {
        safeVote(poll_id, votedBy, votedOn, amount);
        return uint8(voteInfo[msg.sender][poll_id].votingStatus);
    }

    function stop(uint256 poll_id) external {
        voteInfo[msg.sender][poll_id].votingStatus = Status.failed;
    }

    function getStatus(uint256 poll_id) view external returns(uint8){
       return uint8(voteInfo[msg.sender][poll_id].votingStatus); 
    }

    function retrieve(uint256 poll_id) view external 
    returns(uint8, uint40, uint256, uint256, address){
        return (
            uint8(voteInfo[msg.sender][poll_id].votingStatus),
            voteInfo[msg.sender][poll_id].deadline,
            voteInfo[msg.sender][poll_id].votesFor,
            voteInfo[msg.sender][poll_id].votesAgainst,
            voteInfo[msg.sender][poll_id].nominee);
    }

    function getElected(uint256 poll_id) view external returns(address){
       return voteInfo[msg.sender][poll_id].nominee; 
    }

    function getStatusAndElected(uint256 poll_id) view external returns(uint8, address){
        return (uint8(voteInfo[msg.sender][poll_id].votingStatus),
                voteInfo[msg.sender][poll_id].nominee);
    }

    function queryVotes(uint256 poll_id, address votedOn) view external returns(uint256){
        return uint256(votes[msg.sender][poll_id][votedOn]);
    }

    function _updateStatus(uint256 poll_id, address votedOn) internal {
        uint256 _votedOn = votes[msg.sender][poll_id][votedOn];
        Type _votingType = voteInfo[msg.sender][poll_id].votingType;
        if (_votingType == Type.absoluteThreshold){
            if (_votedOn >= uint256(voteInfo[msg.sender][poll_id].threshold)) {
                voteInfo[msg.sender][poll_id].votingStatus = Status.passed;
            }
        } else if (_votingType == Type.permilleThreshold) {
            if (_votedOn >= uint256(voteInfo[msg.sender][poll_id].threshold * voteInfo[msg.sender][poll_id].totalAmount)  / MILLE) {
                voteInfo[msg.sender][poll_id].votingStatus = Status.passed;
            }
        } else if (_votingType == Type.deadline)  {
            // checking majority needs to be handled by calling contract
            if (block.timestamp >= uint256(voteInfo[msg.sender][poll_id].deadline)) {
                voteInfo[msg.sender][poll_id].votingStatus = Status.passed;
            }
        } else if (_votingType == Type.deadlinePermilleThreshold){
            bool afterDeadline = block.timestamp > uint256(voteInfo[msg.sender][poll_id].deadline);
            bool belowThreshold = (_votedOn < uint256(voteInfo[msg.sender][poll_id].threshold * voteInfo[msg.sender][poll_id].totalAmount) / MILLE);
            if ( afterDeadline && belowThreshold){
                voteInfo[msg.sender][poll_id].votingStatus = Status.failed;
            }
            if (!afterDeadline && !belowThreshold){
                voteInfo[msg.sender][poll_id].votingStatus = Status.passed;
            }
              
        } else if (_votingType == Type.deadlineAbsoluteThreshold){
            bool afterDeadline = block.timestamp > uint256(voteInfo[msg.sender][poll_id].deadline);
            bool belowThreshold = _votedOn < uint256(voteInfo[msg.sender][poll_id].threshold);
            if ( afterDeadline && belowThreshold){
                voteInfo[msg.sender][poll_id].votingStatus = Status.failed;
            }
            if (!afterDeadline && !belowThreshold){
                voteInfo[msg.sender][poll_id].votingStatus = Status.passed;
            }
        } else {

        }
    }

    modifier hasAlreadyVoted(uint256 poll_id, address votedBy) {
        require(!alreadyVoted[msg.sender][poll_id][votedBy], "Already voted!");
        _;
    }

    modifier withStatusHandling(uint256 poll_id, address votedBy, address votedOn) {
        require(voteInfo[msg.sender][poll_id].votingStatus==Status.active, "Voting not active!");
        _;
        _updateStatus(poll_id, votedOn);
    }
}
