// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Voting {


    // different kind of stopping rules:
    // deadline
    // majority
    // minAmountOfVotes.

    enum Status {inactive, active, passed, stopped, failed}

    struct PollInfo {
        address caller;
        bytes32[] options;
        bytes32[] parameters;
        bytes4 callback;
        Status status;
        uint256[] votes;
    }


    uint256 pollId;
    mapping(uint256=>PollInfo) pollInfo;
    mapping(uint256=>uint256) pollCounter;
    mapping(address=>bool) public persistance;
    // mapping(address=>uint256) pollIds;
    mapping(address=>mapping(uint256=>uint256)) voteTracker;
    uint256[] _vacant;

    // mapping(address=>mapping(uint256=>mapping(uint256=>uint256))) optionsVote;
    // mapping(address=>mapping(uint256=>mapping(bytes32=>uint256))) freeVote;
    // // mapping(address=>uint256)
    // mapping(address=>mapping(uint256=>mapping(address=>uint256))) voteTracker;

    function changePersistance() external {
        persistance[msg.sender] = !persistance[msg.sender];
    }

    function setPollInfo(
        uint256 index,
        bytes32[] memory options,
        bytes32[] memory parameters,
        bytes4 callback) 
    internal 
    {
        pollInfo[index] = PollInfo({
                caller: msg.sender,
                options: options,
                parameters: parameters,
                callback: callback,
                status: Status.inactive,
                votes: new uint256[](options.length)
            });
    }

    function start(bytes32[] memory options, bytes32[] memory parameters, bytes4 callback) 
    external
    returns(uint256 _pollId, uint256 _pollCounter)
    {
        uint256 index;
        if(_vacant.length>0) {
            index = _vacant[_vacant.length - 1];
            _vacant.pop();
            setPollInfo(index, options, parameters, callback);
            return (index, )
        } else{
            setPollInfo(pollId, options, parameters, callback);
            pollId += 1;  // can it ever exceed the uint modulus
        }
        return 

        
    }

    function optionCast(uint256 _pollId, address _voter, uint256 _option, uint256 _amount) external {
        require(pollInfo[_pollId].caller == msg.sender, "No permission");
        // require(pollInfo[_pollId].options.length <= _option, "No such option");
        require(voteTracker[_voter][_pollId] < pollCounter[_pollId], "Already voted");
        pollInfo[_pollId].votes[_option] += _amount;
        voteTracker[_voter][_pollId] = pollCounter[_pollId];
        _checkPoll(_pollId);
    }

    function _checkPoll(uint256 _pollId) internal {
        // checks the voting parameters which option to choose from.

        // say majority
        if (pollInfo[_pollId].votes[_option] > pollInfo[_pollId].votes[_option]){
            pollInfo[_pollId].status = Status.passed;
            return _option;
        }

        // 
        if (!persistance[msg.sender]){
            _reset(_pollId);
        }
    }



    function stop(uint256 _pollId) external {
        require(pollInfo[_pollId].caller == msg.sender, "No permission");
        require(pollInfo[_pollId].status == Status.active, "No result yet");
        pollInfo[_pollId].status == Status.stopped;
        
    }

    function resume(uint256 _pollId) external {
        require(pollInfo[_pollId].caller == msg.sender, "No permission");
        require(pollInfo[_pollId].status == Status.stopped, "No result yet");
        pollInfo[_pollId].status == Status.active;
    }

    function reset(uint256 _pollId) external {
        require(pollInfo[_pollId].caller == msg.sender, "No permission");
        require(uint8(pollInfo[_pollId].status) >= 2, "still active");
        _reset(_pollId);
    }

    function _reset(uint256 _pollId) internal {
        delete pollInfo[_pollId];
        pollCounter[_pollId] += 1;
        _vacant.push(_pollId);
    }


}