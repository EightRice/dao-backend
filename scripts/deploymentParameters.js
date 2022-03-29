const hre = require('hardhat')

let ZeroAddress = "0x0000000000000000000000000000000000000000"

let deployRepToken = false
let hardcodedRepTokenAddress = "0xDF8A6d7F673834617A1208409162b1C9a35B65A0" 
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
transferToAllDorgHolders = false

module.exports = {
  withClientProjectCreation,
  TypicalMiningDurationInSec,
  useRealDorgAccounts,
  deployRepToken,
  RepTokenAddress,
  transferToAllDorgHolders,
  verbose
}