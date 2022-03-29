// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IRepToken} from "../Token/RepToken.sol";

enum PollStatus {
    active,
    passed,
    implemented,
    noMajority,
    paused,
    tied,
    disapproved,
    failed
}

// TODO: Try with this simpler interface instead of the complicated one from the import
// interface ITokenOnlyBalance {
//     function balanceOf(address account) external view returns (uint256);
// }


struct PollInfo {
        bytes4 motionId;
        bytes callData;
        uint256 pro;
        uint256 contra;
        uint256 deadline;
        uint256 thresholdFraction;      // if threshold = 0, then there is no threshold condition (simple majority)
        uint256 thresholdReference;   // in Basispoints (10_000). If thresholdRef = 0, then threshold is w.r.t TotalVoteWeight, otherwise w.r.t thresholdRef. 
        uint256 totalVotesCast;
        IRepToken repToken; 
        PollStatus pollStatus;
    }

struct DefaultPollValues {
    uint256 maxDuration;
    uint256 thresholdFraction;
    address repTokenAddress;
}

contract Poll {

    uint256 internal THRESHOLD_BASISPOINTS = 10_000;
    bytes4 internal changeDefaultPollValuesIndexForThisMotionId = bytes4(keccak256("changeDefaultPollValuesIndexForThisMotion(bytes4,uint256)"));
    bytes4 internal addAndAdoptNewDefaultPollValuesForThisMotionId = bytes4(keccak256("addAndAdoptNewDefaultPollValuesForThisMotion(bytes4,uint256,uint256,address)"));

    DefaultPollValues[] public defaultPollValues;
    

    uint256 public latestPollIndex = 0;
    mapping(uint256 => PollInfo) public pollInfo;
    mapping(uint256 => mapping(address=>bool)) _alreadyVoted; 
    mapping(bytes4=>uint256) public indexForDefaultPollValue;
    mapping(bytes4 => bool) _allowedMotionId;

    

    function _addNewDefaultPollValues(
        uint256 maxDuration,
        uint256 thresholdFraction,
        address repTokenAddress
    ) internal {
        defaultPollValues.push(DefaultPollValues({
            maxDuration: maxDuration,
            thresholdFraction: thresholdFraction,
            repTokenAddress: repTokenAddress
        }));
    }
    

    
    function changeDefaultPollValuesIndexForThisMotion(bytes4 motionId, uint256 newIndex) external {
        require(_isVoteImplementationCall());
        require(newIndex<defaultPollValues.length);   
        indexForDefaultPollValue[motionId] = newIndex;
    }

    function addAndAdoptNewDefaultPollValuesForThisMotion(
        bytes4 motionId, 
        uint256 maxDuration,
        uint256 thresholdFraction,
        address repTokenAddress)
    external 
    {
        require(_isVoteImplementationCall());
        _addNewDefaultPollValues(maxDuration, thresholdFraction, repTokenAddress);
        indexForDefaultPollValue[motionId] = defaultPollValues.length - 1;
    }
    

    function _startPollWithDefaultValues(
        bytes4 motionId,
        bytes memory callData,
        uint256 thresholdReferenceValue)
    internal
    iterate
    onlyAllowedMotionId(motionId)
    {
        uint256 index = indexForDefaultPollValue[motionId];
        pollInfo[latestPollIndex] = PollInfo({
            motionId: motionId,
            callData: callData,
            pro: 0,
            contra: 0,
            deadline: block.timestamp + defaultPollValues[index].maxDuration,
            thresholdFraction: defaultPollValues[index].thresholdFraction,
            thresholdReference: thresholdReferenceValue,
            totalVotesCast: 0,
            repToken: IRepToken(defaultPollValues[index].repTokenAddress),
            pollStatus: PollStatus.active 
        });
    }

  
    

    function _startPoll(
        bytes4 motionId,
        bytes memory callData,
        uint256 maxDuration,
        uint256 thresholdFraction,
        uint256 thresholdReference,
        address repTokenAddress
    ) 
    internal 
    iterate
    onlyAllowedMotionId(motionId)
    {
        pollInfo[latestPollIndex] = PollInfo({
            motionId: motionId,
            callData: callData,
            pro: 0,  
            contra: 0,
            deadline: block.timestamp + maxDuration,
            thresholdFraction: thresholdFraction,
            thresholdReference: thresholdReference,
            totalVotesCast: 0,
            repToken: IRepToken(repTokenAddress),
            pollStatus: PollStatus.active 
        });
    }



    function _pauseVoting(uint256 pollIndex) internal {
        // deadline temporarily stores the time remaining in seconds.
        pollInfo[pollIndex].deadline = pollInfo[pollIndex].deadline - block.timestamp;
        pollInfo[pollIndex].pollStatus = PollStatus.paused;
    }

    function _resumeVoting(uint256 pollIndex) internal {    
        // deadline is now the time remaining when pause was executed plus the current time.
        pollInfo[pollIndex].deadline = pollInfo[pollIndex].deadline + block.timestamp;  
        pollInfo[pollIndex].pollStatus = PollStatus.active; 
    }

    function _vote(uint256 pollIndex, bool approve) 
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
        uint256 votingPower = (address(pollInfo[pollIndex].repToken) == address(0)) ? pollInfo[pollIndex].repToken.balanceOf(msg.sender) : 1;
        if (approve){
            pollInfo[pollIndex].pro += votingPower;
        } else {
            pollInfo[pollIndex].contra += votingPower;
        } 
        return pollInfo[pollIndex].pollStatus;      
    }

    
    function _updatePollStatus(uint256 pollIndex) internal {

        uint256 totalVotes = pollInfo[pollIndex].pro + pollInfo[pollIndex].contra;

        if (pollInfo[pollIndex].thresholdFraction == 0){
            // considered as: no majority threshold fraction (in Basispoints) is supplied.
            if (pollInfo[pollIndex].pro > pollInfo[pollIndex].contra) {
                // no absolute reference threshold is specified (simple majority)... OR ...
                // the winner has also superseeded an absolute threshold of votes (min absolute threshold).
                bool majorityReached = (pollInfo[pollIndex].thresholdReference == 0) || (pollInfo[pollIndex].pro >= pollInfo[pollIndex].thresholdReference);
                pollInfo[pollIndex].pollStatus = majorityReached ? PollStatus.passed : PollStatus.noMajority;
                return ;
            } else if (pollInfo[pollIndex].pro < pollInfo[pollIndex].contra) {
                bool majorityReached = (pollInfo[pollIndex].thresholdReference == 0) || (pollInfo[pollIndex].contra >= pollInfo[pollIndex].thresholdReference);
                pollInfo[pollIndex].pollStatus = majorityReached ? PollStatus.disapproved : PollStatus.noMajority;
                return ;
            } else {
                // no winner
                pollInfo[pollIndex].pollStatus = PollStatus.tied;
                return ;
            }
        }

        if (pollInfo[pollIndex].pro > pollInfo[pollIndex].contra){
            // check majority
            uint256 referenceValue = (pollInfo[pollIndex].thresholdReference == 0) ? totalVotes : pollInfo[pollIndex].thresholdReference;
            bool majorityReached = pollInfo[pollIndex].pro >= (referenceValue * pollInfo[pollIndex].thresholdFraction) / THRESHOLD_BASISPOINTS;
            pollInfo[pollIndex].pollStatus = majorityReached ? PollStatus.passed : PollStatus.noMajority;
            return ;

        } else if (pollInfo[pollIndex].pro < pollInfo[pollIndex].contra){
            // check majority
            uint256 referenceValue = (pollInfo[pollIndex].thresholdReference == 0) ? totalVotes : pollInfo[pollIndex].thresholdReference;
            bool majorityReached = pollInfo[pollIndex].contra >= (referenceValue * pollInfo[pollIndex].thresholdFraction) / THRESHOLD_BASISPOINTS;
            pollInfo[pollIndex].pollStatus = majorityReached ? PollStatus.disapproved : PollStatus.noMajority;
            return ;

        } else {
            // no winner
            pollInfo[pollIndex].pollStatus = PollStatus.tied;
            return ;
        }

    }


    function _implement(uint256 pollIndex) internal {
        (bool success, ) = address(this).call(abi.encodePacked(pollInfo[pollIndex].motionId, pollInfo[pollIndex].callData));
        pollInfo[pollIndex].pollStatus = success ? PollStatus.implemented : PollStatus.failed;
    }

    function _allowNewMotionId(bytes4 motionId) internal{
        _allowedMotionId[motionId] = true;
    }

    function _batchAllowNewMotionIds(bytes4[] memory motionIds) internal {
        for (uint256 i=0; i<motionIds.length; i++){
            _allowedMotionId[motionIds[i]] = true;
        }
    }

    function _disallowNewMotionId(bytes4 motionId) internal{
        _allowedMotionId[motionId] = false;
    }

    /* VIEW FUNCTIONS */

    function isAllowedMotionId(bytes4 motionId) 
    external
    view 
    returns(bool)
    {
        return _allowedMotionId[motionId];
    }
    // function defaultPollValues

    function getPollStatus(uint256 pollIndex) external view returns(uint16)
    {
        return uint16(pollInfo[pollIndex].pollStatus);
    }

    function getPollCallData(uint256 pollIndex) external view returns(bytes memory)
    {
        return pollInfo[pollIndex].callData;
    }

    function getPollMotionId(uint256 pollIndex) external view returns(bytes4)
    {
        return pollInfo[pollIndex].motionId;
    }

    modifier iterate {
        _;
        latestPollIndex += 1;
    }

    modifier doubleVotingGuard (uint256 pollIndex){
        require(!_alreadyVoted[pollIndex][msg.sender], "Only one vote!");
        _;
        _alreadyVoted[pollIndex][msg.sender] = true;
        pollInfo[pollIndex].totalVotesCast += 1;
    }

    modifier castVote(uint256 pollIndex, bool approve){
        PollStatus newPollstatus = _vote(pollIndex, approve);
        if (newPollstatus == PollStatus.passed || 
            newPollstatus == PollStatus.noMajority ||
            newPollstatus == PollStatus.disapproved ||
            newPollstatus == PollStatus.tied){
            _;
        }
    }

    modifier onlyAllowedMotionId(bytes4 motionId) {
        require(_allowedMotionId[motionId]);
        _;
    }

    // currently the way that the Poll works is that it makes an external call to within the same contract (its more expensive, but this way we can track where voting implementation calls come from.)
    function _isVoteImplementationCall() internal view returns(bool){
        return msg.sender == address(this);
    }
    

}