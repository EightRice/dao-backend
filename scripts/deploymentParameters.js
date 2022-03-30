const hre = require('hardhat')

let ZeroAddress = "0x0000000000000000000000000000000000000000"

let deployRepToken = false
let hardcodedRepTokenAddress = "0x6627dd5c2f95706e1ae12FdD77A91a2B9cC2d964" 
let deployPaymentToken = false
let hardcodedPaymentTokenAddress = "0x2E96A1B24859D4B8b73486199160876962129265"
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
  deployPaymentToken,
  hardcodedPaymentTokenAddress,
  transferToAllDorgHolders,
  verbose
}