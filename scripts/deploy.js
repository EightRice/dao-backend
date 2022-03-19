// const { expect } = require("chai");
// const { expect } = require("chai");
const {ethers} = require("hardhat");

const SIGNERS = {
  ALICE: null,
  BOB: null,
  CHARLIE: null,
  DANIEL: null
}

CONTRACT = {
  SOURCE: null,
  PROJECT: null,
  REPTOKEN: null,
  PAYMENTTOKEN: null
}

ADDRESSES = {
  Source: "",
  RepToken: "",
  Projects: [],
  PaymentTokens: []
}

let tx = null
let receipt = null
let contractName = ""
const InitialSupply = 10000;

async function loadSigners () {
  let allSigners = await ethers.getSigners()
  SIGNERS.ALICE = allSigners[0]
  SIGNERS.BOB = allSigners[1]
  SIGNERS.CHARLIE = allSigners[2]
}


async function deployAll() {
  await loadSigners()
  
  // Deploy PaymentToken
  contractName = "PaymentToken"
  TestPaymentTokenFactory = await ethers.getContractFactory(contractName);
  USDCoin = await TestPaymentTokenFactory.connect(SIGNERS.BOB).deploy("Circle USD", "USDC"); 
  await USDCoin.deployed()
  console.log("The address of " + contractName + " is " + USDCoin.address)
  //

  contractName = "ClientProjectFactory"
  ClientProjectFactoryFactory = await ethers.getContractFactory(contractName);
  clientProjectFactory = await ClientProjectFactoryFactory.connect(SIGNERS.BOB).deploy()
  tx = await clientProjectFactory.deployed()
  console.log("The address of " + contractName + " is " + clientProjectFactory.address)
  // Deploy InternalProjectFactory 

  contractName = "InternalProjectFactory"
  InternalProjectFactoryFactory = await ethers.getContractFactory(contractName);
  internalProjectFactory = await InternalProjectFactoryFactory.connect(SIGNERS.BOB).deploy()
  await internalProjectFactory.deployed()
  console.log("The address of " + contractName + " is " + internalProjectFactory.address)
  

  // Deploy Voting 
  contractName = "Voting"
  VotingFactory = await ethers.getContractFactory(contractName);
  voting = await InternalProjectFactoryFactory.connect(SIGNERS.BOB).deploy()
  await voting.deployed()
  console.log("The address of " + contractName + " is " + voting.address)

  // Deploy Source 
  let initialMembers = [SIGNERS.ALICE.address, SIGNERS.BOB.address, SIGNERS.CHARLIE.address]
  let initialRepPerHolder = ethers.BigNumber.from("1000000000000000000")
  let initialRep = [initialRepPerHolder.mul(100), initialRepPerHolder.mul(100), initialRepPerHolder.mul(100)] 
  contractName = "Source"
  SourceFactory = await ethers.getContractFactory(contractName);
  source = await SourceFactory.connect(SIGNERS.BOB).deploy(
    voting.address,
    initialMembers,
    initialRep)
  await source.deployed()
  console.log("The address of " + contractName + " is " + source.address)

  let repAddress = await source.repToken();
  console.log("The Reptoken address is: ", repAddress)
  // add DeploymentFactories
  tx = await source.setDeploymentFactories(
    clientProjectFactory.address,
    internalProjectFactory.address
  )
  receipt = await tx.wait()
  console.log("Gas used", receipt.gasUsed.toString())

  // add newPaymentToken
  tx = await source.addPaymentToken(USDCoin.address)
  receipt = await tx.wait()
  console.log("Gas used", receipt.gasUsed.toString())


  // set DefaultPaymentToken
  tx = await source.setDefaultPaymentToken(USDCoin.address)
  receipt = await tx.wait()
  console.log("Gas used", receipt.gasUsed.toString())

  // set DefaultPaymentToken
  let defaultPaymentToken = await source.defaultPaymentToken()
  console.log("The source contracts default paymentToken is " + defaultPaymentToken + ".\nThe dummy USDC token is at " + USDCoin.address)
 

  // create Project

  // add PaymentToken

  // // // await USDCoin.deployed();
  // // // Coin2 = await ShitcoinFactory.deploy(InitialSupply); await Coin2.deployed();
  // console.log('Address of clientProjectFactory', clientProjectFactory.address)
  // console.log(await signers[0].getAddress())
}

deployAll()


