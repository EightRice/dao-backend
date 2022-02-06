// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IVoting {
    function start(uint8 _votingType, uint40 _deadline, uint120 _threshold, uint120 _totalAmount) external returns(uint256);
    function vote(uint256 poll_id, address votedBy, address votedOn, uint256 amount) external;
    function safeVote(uint256 poll_id, address votedBy, address votedOn, uint128 amount) external;
    function safeVoteReturnStatus(uint256 poll_id, address votedBy, address votedOn, uint128 amount) external returns(uint8);
    function getStatus(uint256 poll_id) external returns(uint8);
    function getElected(uint256 poll_id) view external returns(address);
    function getStatusAndElected(uint256 poll_id) view external returns(uint8, address);
    function stop(uint256 poll_id) external;
}