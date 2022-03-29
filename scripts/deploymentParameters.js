const hre = require('hardhat')

let ZeroAddress = "0x0000000000000000000000000000000000000000"

let deployRepToken = false
let hardcodedRepTokenAddress = "0x10fE87731dd857a521990b0325cD6b8cde6e00B0" 
let deployPaymentToken = false
let hardcodedPaymentTokenAddress = "0xD29B912635EF2E5F0Bfd9F5dB41DBCDdBBE1426b"
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