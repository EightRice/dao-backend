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
let deployTx = null
let receipt = null
let contractName = ""
const InitialSupply = 10000;

async function loadSigners () {
  let allSigners = await ethers.getSigners()
  SIGNERS.ALICE = allSigners[0]
  SIGNERS.BOB = allSigners[1]
  SIGNERS.CHARLIE = allSigners[2]
}

let ProjectStatus = ["proposal", "active", "inDispute", "inactive", "completed", "rejected"]

function delay(miliseconds){
  return new Promise(function(resolve){
      setTimeout(resolve,miliseconds);
  });
}

async function deployAll() {
  await loadSigners()
  
  // Deploy PaymentToken
  contractName = "PaymentToken"
  TestPaymentTokenFactory = await ethers.getContractFactory(contractName);
  USDCoin = await TestPaymentTokenFactory.connect(SIGNERS.ALICE).deploy("Circle USD", "USDC"); 
  deployTx = await USDCoin.deployTransaction.wait()
  console.log("\t\tGas used for the deployment of " + contractName + " is " + deployTx.gasUsed.toString())
  console.log("The address of " + contractName + " is " + USDCoin.address)
  //

  contractName = "ClientProjectFactory"
  ClientProjectFactoryFactory = await ethers.getContractFactory(contractName);
  clientProjectFactory = await ClientProjectFactoryFactory.connect(SIGNERS.ALICE).deploy()
  deployTx = await clientProjectFactory.deployTransaction.wait()
  console.log("\t\tGas used for the deployment of " + contractName + " is " + deployTx.gasUsed.toString())
  console.log("The address of " + contractName + " is " + clientProjectFactory.address)
  // Deploy InternalProjectFactory 

  contractName = "InternalProjectFactory"
  InternalProjectFactoryFactory = await ethers.getContractFactory(contractName);
  internalProjectFactory = await InternalProjectFactoryFactory.connect(SIGNERS.ALICE).deploy()
  deployTx = await internalProjectFactory.deployTransaction.wait()
  console.log("\t\tGas used for the deployment of " + contractName + " is " + deployTx.gasUsed.toString())
  console.log("The address of " + contractName + " is " + internalProjectFactory.address)
  

  // Deploy Voting 
  contractName = "Voting"
  VotingFactory = await ethers.getContractFactory(contractName);
  voting = await InternalProjectFactoryFactory.connect(SIGNERS.ALICE).deploy()
  deployTx = await voting.deployTransaction.wait()
  console.log("\t\tGas used for the deployment of " + contractName + " is " + deployTx.gasUsed.toString())
  console.log("The address of " + contractName + " is " + voting.address)

  // Deploy Source 
  let initialMembers = [SIGNERS.ALICE.address, SIGNERS.BOB.address, SIGNERS.CHARLIE.address]
  let initialRepPerHolder = ethers.BigNumber.from("1000000000000000000")
  let initialRep = [initialRepPerHolder.mul(100), initialRepPerHolder.mul(100), initialRepPerHolder.mul(100)] 
  contractName = "Source"
  SourceFactory = await ethers.getContractFactory(contractName);
  source = await SourceFactory.connect(SIGNERS.ALICE).deploy(
    voting.address,
    initialMembers,
    initialRep)
  
  deployTx = await source.deployTransaction.wait()
  console.log("\t\tGas used for the deployment of " + contractName + " is " + deployTx.gasUsed.toString())
  console.log("The address of " + contractName + " is " + source.address)

  let repAddress = await source.repToken();
  console.log("The Reptoken address is: ", repAddress)
  // add DeploymentFactories
  tx = await source.setDeploymentFactories(
    clientProjectFactory.address,
    internalProjectFactory.address
  )
  receipt = await tx.wait()
  console.log("\t\tGas used to set the Deployment Factories: ", receipt.gasUsed.toString())

  repToken = await ethers.getContractAt("RepToken", repAddress, SIGNERS.BOB);

  // add newPaymentToken
  tx = await source.connect(SIGNERS.ALICE).addPaymentToken(USDCoin.address)
  receipt = await tx.wait()
  console.log("\t\tGas used to add a new Payment Token to the array: ", receipt.gasUsed.toString())


  // set DefaultPaymentToken
  tx = await source.setDefaultPaymentToken(USDCoin.address)
  receipt = await tx.wait()
  console.log("\t\tGas used to set the default Payment Token: ", receipt.gasUsed.toString())

  // set DefaultPaymentToken
  let defaultPaymentToken = await source.defaultPaymentToken()
  console.log("The source contracts default paymentToken is " + defaultPaymentToken + ".\nThe dummy USDC token is at " + USDCoin.address)
 

  // create Project
  tx = await source.createClientProject(
    SIGNERS.CHARLIE.address,
    SIGNERS.BOB.address,
    defaultPaymentToken
  )
  receipt = await tx.wait()
  console.log("\t\tGas used for the creation of a client Project: ", receipt.gasUsed.toString())

  // // // get Project address

  let clientProjectAddress = await source.clientProjects(0);
  console.log("Client Project Address: ", clientProjectAddress)

  let initialVotingDurationBeforeVote = (await source.initialVotingDuration()).toNumber()

  let firstClientProject = await ethers.getContractAt("ClientProject", clientProjectAddress, SIGNERS.BOB);
  tx = await firstClientProject.connect(SIGNERS.ALICE).voteOnProject(true)
  receipt = await tx.wait()
  console.log("\t\tGas used to vote for the client Project: ", receipt.gasUsed.toString())

  let firststatus = ProjectStatus[(await firstClientProject.status())]
  console.log(`The current status is ${firststatus}.`)

  console.log("waiting for a duration of " + (initialVotingDurationBeforeVote + 2) + " seconds.")


  await source.changeInitialVotingDuration(1000);
  console.log("current Poll", await source.currentPoll(7));
  console.log("Change the initial voting duration");

  await delay((initialVotingDurationBeforeVote + 2) * 1000)

  tx = await firstClientProject.registerVote();
  receipt = await tx.wait()
  console.log("\t\tGas used to register the vote for the client Project: ", receipt.gasUsed.toString())

  
  let votes_pro = ethers.utils.formatEther(await firstClientProject.votes_pro())
  let votes_against = ethers.utils.formatEther(await firstClientProject.votes_against())
  let oldstatus = ProjectStatus[(await firstClientProject.status())]
  
  console.log(`There are ${votes_pro} votes for the project and ${votes_against} votes against. The current status is ${oldstatus}.`)

  tx = await firstClientProject.startProject();
  receipt = await tx.wait()
  console.log("\t\tGas used to start the client Project: ", receipt.gasUsed.toString())
  
  let newstatus = ProjectStatus[(await firstClientProject.status())]
  console.log(`The current status is ${newstatus}.`)

  

}

deployAll()


