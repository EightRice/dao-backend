const hre = require('hardhat')

let ZeroAddress = "0x0000000000000000000000000000000000000000"

let deployRepToken = true
let hardcodedRepTokenAddress = "0x0000000000000000000000000000000000000000" 
let RepTokenAddress = deployRepToken ? ZeroAddress:hardcodedRepTokenAddress
let useRealDorgAccounts = true;
let withClientProjectCreation = true;
let verbose = true
let TypicalMiningDurationInSec = 0;
if (hre.network.name=="localhost") {
  TypicalMiningDurationInSec = 2;
} else {
  TypicalMiningDurationInSec = 45;
}

module.exports = {
  withClientProjectCreation,
  TypicalMiningDurationInSec,
  useRealDorgAccounts,
  deployRepToken,
  RepTokenAddress,
  verbose
}