// const { expect } = require("chai");
// const { expect } = require("chai");
const hre = require("hardhat");
const fs = require('fs');
const csv = require('csv-parser')
const deployParameters = require("./deploymentParameters.js")

const SIGNERS = {
  ALICE: null,
  BOB: null,
  CHARLIE: null
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

let deployInfo = {
  "contractsList": new Array(),
  "contracts": new Object(),
  "calls": new Array(),
  "deploymentVariables": new Object()
}

let ZeroAddress = "0x0000000000000000000000000000000000000000"
let STANDARD_INITIAL_VOTING_DURATION = 300 // in seconds
let oneETH = hre.ethers.utils.parseEther("1.0")

let tx = null
let deployTx = null
let receipt = null
let contractName = ""
let errorMessage = ""
let deploymentArgs = new Array()
const InitialSupply = 10000;

async function loadSigners () {
  let allSigners = await hre.ethers.getSigners()
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

function saveToFile(obj, name) {
  var jsonContent = JSON.stringify(obj, null, 2);
  // console.log(jsonContent);
  
  fs.writeFile(name, jsonContent, 'utf8', function (err) {
      if (err) {
          console.log("An error occured while writing JSON Object to File.");
          return console.log(err);
      }
  
      console.log("JSON file has been saved.");
  });
}


function readCSVAsync (file) {
  return new Promise(function (resolve, reject) {
    let allRows = new Array()
    fs.createReadStream(file)
      .pipe(csv())
      .on('data', (row) => {
        allRows.push(row)
      })
      .on('end', () => {
        // console.log('CSV file successfully processed');
        // allRows.push(row)
        resolve(allRows)
      });
      // reject("dont know why")

  })
}


function updateDeployInfo(
  contractName,
  functionName,
  address,
  gasUsed,
  successFlag,
  errorMessage,
  newContract,
  newContractName,
  newContractAddress,
  verbose){

  let forWhat = functionName=="constructor" ? "the constructor" : functionName;
  if (verbose) {
    console.log("\t\tGas used for " + forWhat + " of " + contractName + " is " + gasUsed)
    if (functionName=="constructor" | newContract){
      console.log("The address of " + newContractName + " is " + newContractAddress)
    }
  }
  if (newContract){
    deployInfo["contractsList"].push({
      "name": newContractName,
      "address": newContractAddress
    })
    deployInfo["contracts"][newContractName] = newContractAddress
  } 
  deployInfo["calls"].push({
    "contract": contractName,
    "address": address,
    "function": functionName,
    "gasUsed": gasUsed,
    "successful": successFlag,
    "errorMessage": successFlag ? "None": errorMessage
  })
}


async function deployAll(
  withClientProjectCreation,
  TypicalMiningDurationInSec,
  useRealDorgAccounts,
  deployRepToken,
  hardcodedRepTokenAddress,
  deployPaymentToken,
  hardcodedPaymentTokenAddress,
  transferToAllDorgHolders,
  verbose)
{
  await loadSigners()
  
  if (deployPaymentToken){

    // Deploy PaymentToken
    contractName = "PaymentToken"
    functionName = "constructor"
    newContract = true
    try {
      TestPaymentTokenFactory = await hre.ethers.getContractFactory(contractName);
      deploymentArgs = ["Mock USDC with 18 decimals", "USDC"]
      USDCCoin = await TestPaymentTokenFactory.connect(SIGNERS.ALICE).deploy(deploymentArgs[0], deploymentArgs[1]); 
      deployInfo["deploymentVariables"][USDCCoin.address] = {
        "name": contractName,
        "variables": ['"Mock USDC with 18 decimals"', '"USDC"']}
      deployTx = await USDCCoin.deployTransaction.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, USDCCoin.address, deployTx.gasUsed.toString(), true, errorMessage, newContract, contractName, USDCCoin.address, verbose)
      
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
  }
  
  //
  contractName = "ClientProjectFactory"
  functionName = "constructor"
  newContract = true
  try {
    ClientProjectFactoryFactory = await hre.ethers.getContractFactory(contractName);
    deploymentArgs = []
    clientProjectFactory = await ClientProjectFactoryFactory.connect(SIGNERS.ALICE).deploy()
    deployInfo["deploymentVariables"][clientProjectFactory.address] = {
      "name": contractName,
      "variables": deploymentArgs}
    deployTx = await clientProjectFactory.deployTransaction.wait()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, clientProjectFactory.address, deployTx.gasUsed.toString(), true, errorMessage, newContract, contractName, clientProjectFactory.address, verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }


  contractName = "InternalProjectFactory"
  functionName = "constructor"
  newContract = true
  try{
    InternalProjectFactoryFactory = await hre.ethers.getContractFactory(contractName);
    deploymentArgs = []
    internalProjectFactory = await InternalProjectFactoryFactory.connect(SIGNERS.ALICE).deploy()
    deployInfo["deploymentVariables"][internalProjectFactory.address] = {
      "name": contractName,
      "variables": deploymentArgs}
    deployTx = await internalProjectFactory.deployTransaction.wait()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, internalProjectFactory.address, deployTx.gasUsed.toString(), true, errorMessage, newContract, contractName, internalProjectFactory.address, verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }

  // Deploy Voting 
  contractName = "Voting"
  functionName = "constructor"
  newContract = true
  try {
    VotingFactory = await hre.ethers.getContractFactory(contractName);
    deploymentArgs = []
    voting = await InternalProjectFactoryFactory.connect(SIGNERS.ALICE).deploy()
    deployInfo["deploymentVariables"][voting.address] = {
      "name": contractName,
      "variables": deploymentArgs}
    deployTx = await voting.deployTransaction.wait()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, voting.address, deployTx.gasUsed.toString(), true, errorMessage, newContract, contractName, voting.address, verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }

  if (deployRepToken){


      // Deploy RepToken
    contractName = "RepToken"
    functionName = "constructor"
    newContract = true
    try {
      deploymentArgs = ["dOrg Reputation Token", "dOrg"]

      RepTokenFactory = await hre.ethers.getContractFactory(contractName);
      repToken = await RepTokenFactory.connect(SIGNERS.ALICE).deploy(deploymentArgs[0], deploymentArgs[1])
      
      deployInfo["deploymentVariables"][repToken.address] = {
        "name": "RepToken",
        "variables": [`"${deploymentArgs[0]}"`, `"${deploymentArgs[1]}"`]}
      
      deployTx = await repToken.deployTransaction.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, repToken.address, deployTx.gasUsed.toString(), true, errorMessage, newContract, "RepToken", repToken.address, verbose)
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
  }

  

  // Deploy Source 
  contractName = "Source"
  functionName = "constructor"
  newContract = true
  try {
    votingAddress = ZeroAddress
    if (deployInfo["contracts"]["Voting"]) {
      votingAddress = deployInfo["contracts"]["Voting"];
    }
    SourceFactory = await hre.ethers.getContractFactory(contractName);
    repTokenAddress = ZeroAddress
    if (deployRepToken){
      if (deployInfo["contracts"]["RepToken"]){
        repTokenAddress = deployInfo["contracts"]["RepToken"];
      }
    } else {
      repTokenAddress = hardcodedRepTokenAddress
      // also update the contracts info
      updateDeployInfo("RepToken", "Already Deployed", repTokenAddress, 0, true, errorMessage, true, "RepToken", repTokenAddress, verbose)
    }

    deploymentArgs = [votingAddress, repTokenAddress]
    source = await SourceFactory.connect(SIGNERS.ALICE).deploy(deploymentArgs[0], deploymentArgs[1])
    
    deployInfo["deploymentVariables"][source.address] = {
      "name": contractName,
      "variables": [`"${deploymentArgs[0]}"`, `"${deploymentArgs[1]}"`]}
  
   deployTx = await source.deployTransaction.wait()
   errorMessage = "None"
    updateDeployInfo(contractName, functionName, source.address, deployTx.gasUsed.toString(), true, errorMessage, newContract, "Source", source.address, verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }

  // attach repToken 
  contractName = "RepToken"
  functionName = "changeDAO"
  newContract = false
  try {
    
    repTokenContract = new Object()
    if (deployRepToken) {
      repTokenContract = await hre.ethers.getContractAt(contractName, deployInfo["contracts"][contractName], SIGNERS.ALICE);
    } else {
      repTokenContract = await hre.ethers.getContractAt(contractName, hardcodedRepTokenAddress, SIGNERS.ALICE);
    }


    // console.log('repContact',repTokenContract)
    tx = await repTokenContract.changeDAO(
      source.address
    )


    receipt = await tx.wait()
    errorMessage = "None"
    repTokenDAO = await repTokenContract.getDAO();
    if (verbose) {
      console.log(`The DAO attribute of the RepToken is set to ${repTokenDAO}. The DAO address is ${source.address}`)
    }
    updateDeployInfo(contractName, functionName, repTokenContract.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "",  verbose)
  }

  let initialMembers = [SIGNERS.ALICE.address, SIGNERS.BOB.address, SIGNERS.CHARLIE.address]
  // initialMembers.push()
  let oneETH = hre.ethers.BigNumber.from("1000000000000000000").mul(1)
  let initialRep = Array(initialMembers.length).fill(oneETH)

  if (useRealDorgAccounts) {
    let dOrgMembers = await readCSVAsync("./data/dorgholders.csv")
    for (let n=0; n<dOrgMembers.length; n++) {
      memberAccount = dOrgMembers[n]["HolderAddress"]
      memberRepAmount = oneETH.mul(parseInt(dOrgMembers[n]["Balance"]))
      initialMembers.push(memberAccount)
      initialRep.push(memberRepAmount)
      // console.log(`The Account is ${memberAccount} and the amount is ${memberRepAmount}`)
    }
    // console.log(initialRep)
  }
  
  
  if (deployRepToken) {

    contractName = "Source"
    functionName = "importMembers"
    newContract = false
    // add initial TokenHolders
    

    try {
      // console.log('initialRep', initialRep)
      tx = await source.connect(SIGNERS.ALICE).importMembers(
        initialMembers,
        initialRep
      )
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "",  verbose)
    }
  }
  

  contractName = "Source"
  functionName = "repToken Attribute View"
  newContract = false
  try {
    let repAddress = await source.repToken();
    if (verbose){
      console.log("The repToken is deployed at ", repAddress)
    }
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, source.address, 0, true, errorMessage, newContract, "RepToken", repAddress, verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }

  // add DeploymentFactories
  contractName = "Source"
  functionName = "setDeploymentFactories"
  newContract = false
  try {
    tx = await source.setDeploymentFactories(
      clientProjectFactory.address,
      internalProjectFactory.address
    )
    receipt = await tx.wait()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "",  verbose)
  }

  contractName = "PaymentToken"
  defaultPaymentToken = new Object()
  if (deployInfo["contracts"][contractName]) {
    defaultPaymentToken = await hre.ethers.getContractAt(contractName, deployInfo["contracts"][contractName], SIGNERS.BOB);
  } else {
    defaultPaymentToken = await hre.ethers.getContractAt(contractName, hardcodedRepTokenAddress, SIGNERS.BOB);
  }


  if (deployPaymentToken){

    contractName = "PaymentToken"
    functionName = "freeMint"
    try {
      let maxAllowance = await defaultPaymentToken.maxFreeMintingAllowance()
      let richSigner = SIGNERS.ALICE;
      tx = await defaultPaymentToken.connect(richSigner).freeMint(maxAllowance)
      receipt = await tx.wait()

      errorMessage = "None"
      updateDeployInfo(contractName, functionName, defaultPaymentToken.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
      
      let balance = await defaultPaymentToken.balanceOf(richSigner.address)
      let donation = oneETH.mul(1000)
      console.log("Account " + richSigner.address + " has " + hre.ethers.utils.formatEther(balance))
      console.log("She should transfer about this much to each account: " + hre.ethers.utils.formatEther(donation))

      if (transferToAllDorgHolders){

        AnotherFunctionName = "transfer"
        try {
          let totalGas = hre.ethers.BigNumber.from("0");
          for (let i=0; i<initialMembers.length; i++) {
            if (initialMembers[i] == richSigner.address){
              continue
            }
            tx = await defaultPaymentToken.connect(richSigner).transfer(initialMembers[i], donation);
            receipt = await tx.wait()
            let balance = await defaultPaymentToken.balanceOf(initialMembers[i])
            console.log("Account " + initialMembers[i] + " has " + balance.toString())
            totalGas = totalGas.add(receipt.gasUsed)
          }
          errorMessage = "None"
          updateDeployInfo(contractName, AnotherFunctionName, defaultPaymentToken.address, totalGas.toString(), true, errorMessage, newContract, "", "", verbose)
        } catch(err) {
          updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
        }
        
      }
      
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
  }
  
  

  // add newPaymentToken
  contractName = "Source"
  functionName = "addPaymentToken"
  newContract = false
  try {
    let oneETH = hre.ethers.BigNumber.from("1000000000000000000").mul(1)
    let paymentTokenAddress = deployPaymentToken ? USDCCoin.address : hardcodedPaymentTokenAddress

    tx = await source.connect(SIGNERS.ALICE).addPaymentToken(paymentTokenAddress, oneETH)
    receipt = await tx.wait()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }



  // set DefaultPaymentToken
  contractName = "Source"
  functionName = "setDefaultPaymentToken"
  newContract = false
  try {
    let paymentTokenAddress = deployPaymentToken ? USDCCoin.address : hardcodedPaymentTokenAddress
    tx = await source.setDefaultPaymentToken(paymentTokenAddress)
    receipt = await tx.wait()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }

  // set DefaultPaymentToken
  contractName = "Source"
  functionName = "defaultPaymentToken Attribute View"
  newContract = false
  try {
    let defaultPaymentToken = await source.defaultPaymentToken()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, defaultPaymentToken, 0, true, errorMessage, newContract, "", "", verbose)
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }

  // let initialVotingDurationBeforeVote = (await source.initialVotingDuration()).toNumber()
  let initialVotingDurationBeforeVote = TypicalMiningDurationInSec

  if (withClientProjectCreation){

    // set voting duration low
    contractName = "Source"
    functionName = "changeInitialVotingDuration"
    newContract = false
    try {
      tx = await source.changeInitialVotingDuration(initialVotingDurationBeforeVote);
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
      if (verbose) {
        console.log("Change the initial voting duration to " + (await source.initialVotingDuration()).toString());
      }
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }

    contractName = "PaymentToken"
    defaultPaymentTokenAddress = deployPaymentToken ? USDCCoin.address : hardcodedPaymentTokenAddress


    // create Project
    contractName = "Source"
    functionName = "createClientProject"
    newContract = true
    try {
      
      tx = await source.connect(SIGNERS.ALICE).createClientProject(
        SIGNERS.CHARLIE.address,  // sourcing 
        SIGNERS.BOB.address,
        defaultPaymentTokenAddress
      )
      receipt = await tx.wait()
      let clientProjectAddress = await source.clientProjects(0);
      
      let repTokenAddress = await source.repToken();
      let arbitrationEscrowAddress = await source.arbitrationEscrow();
      let votingAddress = await source.voting();
      let votingDuration = (await source.initialVotingDuration()).toString();

      deployInfo["deploymentVariables"][clientProjectAddress] = {
        "name": "ClientProject",
        "variables": [
          `"${source.address}"`,
          `"${SIGNERS.ALICE.address}"`,
          `"${SIGNERS.CHARLIE.address}"`,
          `"${SIGNERS.BOB.address}"`,
          `"${repTokenAddress}"`,
          `"${arbitrationEscrowAddress}"`,
          `"${votingAddress}"`,
          `"${defaultPaymentTokenAddress}"`,
          `${votingDuration}`]}
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "clientProjectNumberOne", clientProjectAddress, verbose)
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }

    contractName = "ClientProject"
    firstClientProject = new Object()
    if (deployInfo["contracts"]["clientProjectNumberOne"]) {
      firstClientProject = await hre.ethers.getContractAt(contractName, deployInfo["contracts"]["clientProjectNumberOne"], SIGNERS.BOB);
    }
    functionName = "voteOnProject"
    newContract = false
    try {
      tx = await firstClientProject.connect(SIGNERS.ALICE).voteOnProject(true)
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
      let firststatus = ProjectStatus[(await firstClientProject.status())]

      if (verbose) {
        console.log(`The current status is ${firststatus}.`)
      }
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
    
    if (verbose) {
      console.log("waiting for a duration of " + (initialVotingDurationBeforeVote + 2) + " seconds.")
    }
    await delay((initialVotingDurationBeforeVote + 2) * 1000)

    contractName = "ClientProject"
    functionName = "registerVote"
    newContract = false
    try {
      tx = await firstClientProject.registerVote();
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
      let votes_pro = hre.ethers.utils.formatEther(await firstClientProject.votes_pro())
      let votes_against = hre.ethers.utils.formatEther(await firstClientProject.votes_against())
      let oldstatus = ProjectStatus[(await firstClientProject.status())]
      if (verbose) {
        console.log(`There are ${votes_pro} votes for the project and ${votes_against} votes against. The current status is ${oldstatus}.`)
      }

    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
    
    contractName = "ClientProject"
    functionName = "startProject"
    newContract = false
    try {
      tx = await firstClientProject.connect(SIGNERS.ALICE).startProject();
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
      let newstatus = ProjectStatus[(await firstClientProject.status())]
      if (verbose){
        console.log(`The current status is ${newstatus}.`)
      }
        
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
    


    contractName = "InternalProject"
    functionName = "createInternalProject"
    newContract = true
    try {
      let _requestedAmounts = oneETH.mul(4180)
      let _requestedMaxAmountPerPaymentCycle = oneETH.mul(105);
      tx = await source.connect(SIGNERS.ALICE).createInternalProject(
        _requestedAmounts,
        _requestedMaxAmountPerPaymentCycle
      );
      receipt = await tx.wait()
      errorMessage = "None"

      let internalProjectAddress = await source.internalProjects(0);
    
      let votingDuration = (await source.initialVotingDuration()).toNumber()
      let paymentInterval = (await source.paymentInterval()).toNumber()
      deployInfo["deploymentVariables"][internalProjectAddress] = {
        "name": "InternalProject",
        "variables": [
          `"${source.address}"`,
          `"${SIGNERS.ALICE.address}"`,
          `"${votingAddress}"`,
          `${votingDuration}`,
          `${paymentInterval}`,
          `"${_requestedAmounts.toString()}"`,
          `"${_requestedMaxAmountPerPaymentCycle.toString()}"`]}
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "firstInternalProject", internalProjectAddress, verbose)
        
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
    
    contractName = "InternalProject"
    firstInternalProject = new Object()
    if (deployInfo["contracts"]["firstInternalProject"]) {
      firstInternalProject = await hre.ethers.getContractAt(contractName, deployInfo["contracts"]["firstInternalProject"], SIGNERS.BOB);
    }
    functionName = "voteOnProject"
    newContract = false
    try {

      tx = await firstInternalProject.connect(SIGNERS.ALICE).voteOnProject(true)
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, firstInternalProject.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }

    if (verbose) {
      console.log("waiting for a duration of " + (initialVotingDurationBeforeVote + 2) + " seconds.")
    }
    await delay((initialVotingDurationBeforeVote + 2) * 1000)
    
    contractName = "InternalProject"
    functionName = "registerVote"
    newContract = false
    try {

      tx = await firstInternalProject.connect(SIGNERS.ALICE).registerVote()
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, firstInternalProject.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }


  }

  else {
    // use up one alteration of the initial voting duration

    // set voting duration low
    contractName = "Source"
    functionName = "changeInitialVotingDuration"
    newContract = false
    try {
      tx = await source.changeInitialVotingDuration(initialVotingDurationBeforeVote);
      receipt = await tx.wait()
      errorMessage = "None"
      updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
      if (verbose) {
        console.log("Change the initial voting duration to " + (await source.initialVotingDuration()).toString());
      }
    } catch(err) {
      updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
    }
  }

  
  contractName = "Source"
  functionName = "changeInitialVotingDuration"
  newContract = false
  try {
    tx = await source.changeInitialVotingDuration(STANDARD_INITIAL_VOTING_DURATION);
    receipt = await tx.wait()
    errorMessage = "None"
    updateDeployInfo(contractName, functionName, source.address, receipt.gasUsed.toString(), true, errorMessage, newContract, "", "", verbose)
    if (verbose) {
      console.log("Change the initial voting duration to " + (await source.initialVotingDuration()).toString());
    }
  } catch(err) {
    updateDeployInfo(contractName, functionName, "None", 0, false, err.toString(), newContract, "", "", verbose)
  }

  saveToFile(deployInfo["contractsList"], `./info/${hre.network.name}/contract-list.json`)
  saveToFile(deployInfo["contracts"], `./info/${hre.network.name}/contracts.json`)
  saveToFile(deployInfo["calls"] , `./info/${hre.network.name}/deployment-contract-calls.json`)
  saveToFile(deployInfo["deploymentVariables"] , `./info/${hre.network.name}/deployment-variables.json`)

  
}

// let deployRepToken = true
// let hardcodedRepTokenAddress = "0x0000000000000000000000000000000000000000" 
// let repTokenAddress = deployRepToken ? ZeroAddress:hardcodedRepTokenAddress
// let useRealDorgAccounts = true;
// let withClientProjectCreation = true;
// let verbose = true
// let TypicalMiningDurationInSec = 0;
// if (hre.network.name=="localhost") {
//   TypicalMiningDurationInSec = 2;
// } else {
//   TypicalMiningDurationInSec = 45;
// }

deployAll(
  deployParameters.withClientProjectCreation,
  deployParameters.TypicalMiningDurationInSec,
  deployParameters.useRealDorgAccounts,
  deployParameters.deployRepToken,
  deployParameters.RepTokenAddress,
  deployParameters.deployPaymentToken,
  deployParameters.hardcodedPaymentTokenAddress,
  deployParameters.transferToAllDorgHolders,
  deployParameters.verbose)


// fs.readFile("./data/dorgholders.csv", function (err, fileData) {
//   parse(fileData, {columns: false, trim: true}, function(err, rows) {
//     // Your CSV data is in an array of arrys passed to this callback as rows.
//     console.log(rows)
//   })
// })

// const util = require('util');

// fs.createReadStream("./data/dorgholders.csv")
//   .pipe(csv())
//   .on('data', (row) => {
//     console.log(row);
//   })
//   .on('end', () => {
//     console.log('CSV file successfully processed');
//   });





// async function hallo () {
//   let bla = await readCSVAsync("./data/dorgholders.csv")
//   // console.log(typeof(bla))
//   console.log(bla[0])
// }

// hallo()