// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IRepTokenForVoting {
    /// @dev Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256);
}


contract Voting {

    IRepTokenForVoting repToken;
    // different kind of stopping rules:
    // deadline
    // majority
    // minAmountOfVotes.

    enum Status {inactive, active, passed, stopped, failed}

    /// Store `x`.
    /// @param caller: the contract that calls the poll
    /// @param options: the options that the caller can choose from
    /// @param parameters: encoded the specs for the vote, respectively in bytes32.
    /// @param callback: the function interfaceId to be called by the calling contract.
    /// @param status: the status of this poll.
    /// @param votes: recording the votes for this poll.
    /// @dev 
    struct PollInfo {
        address caller;
        bytes32[] options;
        bytes32[] parameters;
        bytes32 tokenParameter;
        bytes4 callback;
        Status status;
        uint256[] votes;
        uint256 startTime;
    }


    uint256 pollId;  // keeping track of the polls by enumerating them.
    uint256[] _vacant;  // polls that can be reused
    mapping(uint256=>PollInfo) pollInfo;  // keeps track of all the polls, indexed by pollId
    mapping(uint256=>uint256) pollCounter;  // since we reuse polls, each poll has a pollcounter.
    mapping(address=>bool) public persistance;   // a flag that determines whether the caller wishes to persist the data into the storage trie.
    mapping(address=>mapping(uint256=>uint256)) voteTracker;  // keeps track of whether a voter has already voted on a particular poll


    function changePersistance() external {
        persistance[msg.sender] = !persistance[msg.sender];
    }

    function _setPollInfo(
        uint256 index,
        bytes32[] memory options,
        bytes32[] memory parameters,
        bytes32 tokenParameter,
        bytes4 callback) 
    internal 
    {
        pollInfo[index] = PollInfo({
                caller: msg.sender,
                options: options,
                parameters: parameters,
                tokenParameter: tokenParameter,
                callback: callback,
                status: Status.inactive,
                votes: new uint256[](options.length),
                startTime: block.timestamp
            });
    }

    

    function cast(uint256 _pollId, address _voter, uint256 _option) 
    external 
    onlyCaller(_pollId)
    doubleVotingGuard(_pollId, _voter)
    {        
        pollInfo[_pollId].votes[_option] += _getVotingPower(_pollId, _voter);

        // // function signature string should not have any spaces
        // (bool success, bytes memory result) = addr.call(abi.encodeWithSignature("myFunction(uint,address)", 10, msg.sender));
        // (uint a, uint b) = abi.decode(result, (uint, uint));
        
    }

    
    function _getVotingPower(uint256 _pollId, address _voter) internal returns(uint256){
        return ((uint16(bytes2(pollInfo[_pollId].tokenParameter) & 0x0008)!=0) ? repToken.balanceOf(_voter) : 1;
    }

    modifier doubleVotingGuard(uint256 _pollId, address _voter) {
        require(voteTracker[_voter][_pollId] < pollCounter[_pollId], "Already voted");
        _;
        voteTracker[_voter][_pollId] = pollCounter[_pollId];
    }


    function _statusCheck(uint256 _pollId) internal {
        // checks the voting parameters which option to choose from.
        for (uint256 j; j<pollInfo[_pollId].parameters.length; j++){
            bytes32 memory param = pollInfo[_pollId].parameters[j];
            uint8 flag = uint8(bytes1(param));
            bytes1 argByte = bytes1(parameter << 8);
            setArgs = uint8(argByte >> 3);

            if (flag==1) {
                // threshold vote
                if (setArgs==)
                arg1 = uint72(bytes9(parameter << 8 * 3));
                arg2 = uint72(bytes9(parameter << 8 * 12));


            }

            pollInfo[_pollId].votes[_option] += _amount;

        }
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

    function start(bytes32[] memory options, bytes32[] memory parameters, bytes32 tokenParameter, bytes4 callback) 
    external
    returns(uint256, uint256)
    {
        if(_vacant.length>0) {
            pollId = _vacant[_vacant.length - 1];
            _vacant.pop();
            _setPollInfo(pollId, options, parameters, callback);
            return (pollId, 0);
        } else{
            _setPollInfo(pollId, options, parameters, callback);
            pollId += 1;  // can it ever exceed the uint modulus
            return (pollId, pollCounter[pollId]);
        }   
    }

    function stop(uint256 _pollId) external onlyCaller(_pollId) {
        require(pollInfo[_pollId].status == Status.active, "No result yet");
        pollInfo[_pollId].status == Status.stopped;
    }

    function resume(uint256 _pollId) external onlyCaller(_pollId) {
        require(pollInfo[_pollId].status == Status.stopped, "No result yet");
        pollInfo[_pollId].status == Status.active;
    }

    function reset(uint256 _pollId) external onlyCaller(_pollId) {
        require(uint8(pollInfo[_pollId].status) >= 2, "still active");
        _reset(_pollId);
    }

    function _reset(uint256 _pollId) internal {
        delete pollInfo[_pollId];
        pollCounter[_pollId] += 1;
        _vacant.push(_pollId);
    }


    /**
    * STANDARD ENCODINGS FOR REFERENCE
    **/

    function encodeRepTokenParameter(bool setArg1, address tokenAddress, )
    public 
    pure 
    returns(bytes32)
    {
        uint8 pollType = 0;
        uint8 argByteLength = 20;
        uint8 setArgs = 1; // number of arguments (smaller or equal to 5)
        setArgs += (setArg1 ? 2**3: 0); 
        return bytes32(abi.encodePacked(pollType, setArgs, argByteLength, tokenAddress);
    }

    function encodeThresholdParameter(bool setArg1, bool setArg2, bool setArg3, bool lowerThresholdFlag, uint16 permille, uint208 threshold)
    public
    pure 
    returns(bytes32)
    {
        uint8 pollType = 1;
        uint8 argByteLength = 20;  // could be substituted by an encoding of arg lengths.
        uint8 setArgs = 3; // number of arguments (smaller or equal to 5)
        setArgs += (setArg1 ? 2**3: 0); 
        setArgs += (setArg2 ? 2**4: 0);
        setArgs += (setArg3 ? 2**5: 0);
        return bytes32(abi.encodePacked(pollType, setArgs, argByteLength, lowerThresholdFlag, permille, threshold));
    }

    function encodeDurationParameter(bool setArg1, bool setArg2, bool setArg3, uint72 minDuration, uint72 maxDuration, uint72 extendedDuration) 
    public 
    pure 
    returns(bytes32)
    {
        uint8 pollType = 2;
        uint8 argByteLength = 9;
        uint8 setArgs = 3; // number of arguments (smaller or equal to 5)
        setArgs += (setArg1 ? 2**3: 0); 
        setArgs += (setArg2 ? 2**4: 0);
        setArgs += (setArg3 ? 2**5: 0);
        return bytes32(abi.encodePacked(pollType, setArgs, argByteLength, minDuration, maxDuration, extendedDuration));

    }

    function encodeMajorityParameter(bool setArg1, bool setArg2, bool relativeMajority, uint16 permilleOfTotalVotes)
    public
    pure 
    returns(bytes32)
    {
        uint8 pollType = 3;
        uint8 argByteLength = 2;  // could be substituted by an encoding of arg lengths.
        uint8 setArgs = 2; // number of arguments (smaller or equal to 5)
        setArgs += (setArg1 ? 2**3: 0); 
        setArgs += (setArg2 ? 2**4: 0);
        return bytes32(abi.encodePacked(pollType, setArgs, argByteLength, relativeMajority, permilleOfTotalVotes));
    }

   /**
    * MODIFIERS
    **/


    modifier onlyCaller(uint256 _pollId) {
        require(pollInfo[_pollId].caller == msg.sender, "No permission");
        _;
    }


}