

// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.7;


// import {IRepToken} from "../Token/IRepToken.sol";

// import {Poll, PollStatus, DefaultPollValues} from "../Voting/Poll.sol";


// contract A is Poll {

//     IRepToken public repToken;

//     mapping(address=>string) public greetings;

//     bytes4 public sayHalloToUserId = bytes4(keccak256("sayHalloToUser(address)"));

//     constructor() {
//         // maxDuration = 10 Days
//         // Threshold = 50% (absolute majority) of total votes (thresholdReferenceValue)
//         // Quorum = 20% (participation) of possible votes (quorumReferenceValue)
//         _addNewDefaultPollValues(10 days, int256(5_000), int256(2_000), address(repToken));
//     }


//     function startPoll(
//             bytes4 implementedFunctionId,
//             address value,
//             uint256 thresholdReferenceValue,
//             uint256 quorumReferenceValue)
//     external
//     {
//         require(owner == msg.sender, "sorry, only for the owner");
//         _startPollWithDefaultValues(
//             implementedFunctionId,
//             bytes32(abi.encode(value)),
//             thresholdReferenceValue,
//             quorumReferenceValue);
//     }

//     function sayHalloToUser(uint256 pollIndex, uint256 optionIndex) 
//     external
//     castVote(pollIndex, optionIndex) 
//     {
//         address user = abi.decode(bytes(pollInfo[pollIndex].value), (address));
//         greetings[user] = "hallo";
//     }
// }