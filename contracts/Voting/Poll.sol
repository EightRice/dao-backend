// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;



enum PollStatus {
    active,
    paused,
    passed,
    failed,
    noQuorum,
    noMajority,
    tied
}



interface IRepTokenOnlyBalance {
    function balanceOf(address account) external view returns (uint256);
}


struct PollInfo {
        bytes4 implementedFunctionId;
        bytes32 value;
        uint256[] votes;
        uint256 maxIndex;
        uint256 deadline;
        int256 threshold;       // if threshold < 0, then there is no threshold condition
        uint256 thresholdRef;   // in Basispoints (10_000). If thresholdRef = 0, then threshold is w.r.t TotalVoteWeight, otherwise w.r.t thresholdRef. 
        uint256 totalVotesCast;
        int256 quorum;          // if quorum < 0, then there is no quorum.
        uint256 quorumRef;      //  in Basispoints (10_000) measures the totality of possible turnout.
        IRepTokenOnlyBalance repToken; 
        PollStatus pollStatus;
    }

struct DefaultPollValues {
    uint256 maxDuration;
    int256 threshold;
    int256 quorum;
    address repTokenAddress;
}

contract Poll {

    int256 internal THRESHOLD_BASISPOINTS = 10_000;

    DefaultPollValues[] public defaultPollValues;

    uint256 public latestPollIndex = 0;
    mapping(uint256 => PollInfo) public pollInfo;
    mapping(uint256 => mapping(address=>bool)) _alreadyVoted; 

    function _addNewDefaultPollValues(
        uint256 maxDuration,
        int256 threshold,
        int256 quorum,
        address repTokenAddress
    ) internal {
        defaultPollValues.push(DefaultPollValues({
            maxDuration: maxDuration,
            threshold: threshold,
            quorum: quorum,
            repTokenAddress: repTokenAddress
        }));
    }
    
    // function startPoll(
    //     bytes4 implementedFunctionId,
    //     address option,
    //     uint256 thresholdReferenceValue,
    //     uint256 quorumReferenceValue)
    // external
    // {
    //     bytes32[] memory options;
    //     options[0] = bytes32(abi.encode(option));
    //     _startPollWithDefaultValues(
    //         implementedFunctionId,
    //         options,
    //         thresholdReferenceValue,
    //         quorumReferenceValue);
    // }

    mapping(bytes4=>uint256) public indexForDefaultPollValue;

    function _startPollWithDefaultValues(
        bytes4 implementedFunctionId,
        bytes32 value,
        uint256 thresholdReferenceValue,
        uint256 quorumReferenceValue)
    internal
    {
        uint256 index = indexForDefaultPollValue[implementedFunctionId];
        _startPoll(
            implementedFunctionId,
            value,
            defaultPollValues[index].maxDuration,
            defaultPollValues[index].threshold,
            thresholdReferenceValue,
            defaultPollValues[index].quorum,
            quorumReferenceValue,
            defaultPollValues[index].repTokenAddress
        );
    }

  

    function _startPoll(
        bytes4 implementedFunctionId,
        bytes32 value,
        uint256 maxDuration,
        int256 threshold,
        uint256 thresholdRef,
        int256 quorum,
        uint256 quorumRef,
        address repTokenAddress
    ) 
    internal 
    iterate
    {
        pollInfo[latestPollIndex] = PollInfo({
            implementedFunctionId: implementedFunctionId,
            value: value,
            votes: new uint256[](2),  // all the options and against
            maxIndex: 0,
            deadline: block.timestamp + maxDuration,
            threshold: threshold,
            thresholdRef: thresholdRef,
            totalVotesCast: 0,
            quorum: quorum,
            quorumRef: quorumRef,
            repToken: IRepTokenOnlyBalance(repTokenAddress),
            pollStatus: PollStatus.active 
        });
    }


    function _pauseVoting(uint256 pollIndex) internal {
        pollInfo[pollIndex].pollStatus = PollStatus.paused;
    }

    function _resumeVoting(uint256 pollIndex) internal {        
        pollInfo[pollIndex].pollStatus = block.timestamp <= pollInfo[pollIndex].deadline ? PollStatus.active : PollStatus.failed; 
    }

    function _vote(uint256 pollIndex, uint256 optionIndex) 
    internal 
    doubleVotingGuard(pollIndex)
    returns(PollStatus)
    {
        require(pollInfo[pollIndex].pollStatus == PollStatus.active);
        if (block.timestamp > pollInfo[pollIndex].deadline){
            // update pollStatus based on result
            _updatePollStatus(pollIndex);
            return pollInfo[pollIndex].pollStatus;
        }
        // add voting weight to the votes
        pollInfo[pollIndex].votes[optionIndex] += (address(pollInfo[pollIndex].repToken) == address(0)) ? pollInfo[pollIndex].repToken.balanceOf(msg.sender) : 1;  
        return pollInfo[pollIndex].pollStatus;      
    }

    
    function _updatePollStatus(uint256 pollIndex) internal {

        int256 totalVoteWeight = 0;
        uint256 maxIndex = 0;
        uint256 maxVotes = pollInfo[pollIndex].votes[maxIndex];
        bool tie = false;
        for (uint256 i=1; i<pollInfo[pollIndex].votes.length; i++){
            totalVoteWeight += int256(pollInfo[pollIndex].votes[i]);
            if (pollInfo[pollIndex].votes[i] > maxVotes){
                tie = false;
                maxVotes = pollInfo[pollIndex].votes[i];
                maxIndex = i;
            }
            if (pollInfo[pollIndex].votes[i] == maxVotes){
                tie = true;
            }
            // the last exclusive case is that the votes[i] are smaller than the current maxVotes, in which case all the temporary variables stay as they are.
        }
        pollInfo[pollIndex].maxIndex = maxIndex;

        // get total votes casted (either weighted or by address)
        int256 totalVotes = (address(pollInfo[pollIndex].repToken) == address(0)) ? totalVoteWeight : int256(pollInfo[pollIndex].totalVotesCast);

        // check quorum (participation minimum threshold)
        
        if ((pollInfo[pollIndex].quorum >= 0) &&
            (totalVotes < (int256(pollInfo[pollIndex].quorumRef) * pollInfo[pollIndex].quorum) / THRESHOLD_BASISPOINTS)) {
            pollInfo[pollIndex].pollStatus = PollStatus.noQuorum;
            return ;
        }

        // no winner
        if (tie) {
            pollInfo[pollIndex].pollStatus = PollStatus.tied;
            return ;
        }

        // check majority condition
        if (pollInfo[pollIndex].threshold >= 0) {
            bool thrCondition = false;
            if (pollInfo[pollIndex].thresholdRef == 0) {
                // measure votes relative to totalVotes
                thrCondition = int256(pollInfo[pollIndex].votes[maxIndex]) >= (totalVotes * pollInfo[pollIndex].threshold) / THRESHOLD_BASISPOINTS;
            } else {
                // measure votes relative to thresholdRef
                thrCondition = int256(pollInfo[pollIndex].votes[maxIndex]) >= (int256(pollInfo[pollIndex].thresholdRef) * pollInfo[pollIndex].threshold) / THRESHOLD_BASISPOINTS;
            }   
            if (thrCondition) {
                pollInfo[pollIndex].pollStatus = PollStatus.noMajority;
                return ;
            }
            // pollInfo[pollIndex].pollStatus = thrCondition ? PollStatus.passed : PollStatus.noMajority;
            // return ;
        } 
        // else: simple majority

        // TODO: We assume that option 0 is Reject, option 1 is Approve
        // But what if we have multiple options.
        pollInfo[pollIndex].pollStatus = (maxIndex == 1) ? PollStatus.passed : PollStatus.failed;



       
    }


    modifier iterate {
        _;
        latestPollIndex += 1;
    }

    modifier doubleVotingGuard (uint256 pollIndex){
        require(!_alreadyVoted[pollIndex][msg.sender], "1 vote!");
        _;
        _alreadyVoted[pollIndex][msg.sender] = true;
        pollInfo[pollIndex].totalVotesCast += 1;
    }

    modifier castVote(uint256 pollIndex, uint256 optionIndex){
        PollStatus newPollstatus = _vote(pollIndex, optionIndex);
        if (newPollstatus == PollStatus.passed){
            _;
        }
    }
    

}