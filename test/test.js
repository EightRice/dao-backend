// const { expect } = require("chai");
// const { expect } = require("chai");
const hre = require("hardhat");

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

PARAMS = {
  votingDuration: 3,  // 3 seconds
  firstMsAmount: 57,  // Milestone amount
  invoicedMsAmount: 47,   // Invoiced Milestone amount
  clientApprovedMsAmount: 50   // Amount approved by Client
}

describe("Deployment", function () {
  it("Should store the signers and contract instances.", async function() {
    const accounts = await ethers.getSigners()
    SIGNERS.ALICE=accounts[0]  // Arbiter
    SIGNERS.BOB=accounts[1]  // Builder
    SIGNERS.CHARLIE=accounts[2]  // Client
    SIGNERS.DAVE=accounts[3]  // Developer
    SIGNERS.SUSANNE=accounts[4]  // Sourcing Lead
    // initialize all the contracts
    CONTRACT.SOURCE = await hre.ethers.getContractFactory("Source");
    // console.log(CONTRACT.SOURCE)
  });
  it("Should deploy the source contract by Bob (dOrg Builder).", async function () {
    SourceFactory = await ethers.getContractFactory("Source", SIGNERS.BOB);
    Source = await SourceFactory.deploy();
    tx = await Source.deployed();
    // console.log('Deployed to: ', Source.address)
    // console.log('Deployed by: ', SIGNERS.BOB.address)
    ADDRESSES["Source"] = Source.address
    ADDRESSES["RepToken"] = await Source.repToken()

    CONTRACT.SOURCE = await hre.ethers.getContractAt("Source", ADDRESSES["Source"])
    CONTRACT.REPTOKEN = await hre.ethers.getContractAt("RepToken", ADDRESSES["RepToken"])
    // // wait until the transaction is mined
    // await setGreetingTx.wait();
    // expect(1==1)

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
  it ("Some people (say Bob, Dave and Susanne) mint themselves dOrg Rep Tokens (REMOVE IN PRODUCTION!)", async function(){
    const FreeAmount = 100;
    tx = await CONTRACT.REPTOKEN.connect(SIGNERS.BOB).FREEMINTING(FreeAmount); await tx.wait();
    tx = await CONTRACT.REPTOKEN.connect(SIGNERS.DAVE).FREEMINTING(FreeAmount); await tx.wait();
    tx = await CONTRACT.REPTOKEN.connect(SIGNERS.SUSANNE).FREEMINTING(FreeAmount); await tx.wait();
  });
});
describe("Creating and voting on a Project", function () {
  it("Charlie should create three shit-coins, coincientally also called DRT", async function(){
    const InitialSupply = 10000;
    ShitcoinFactory = await ethers.getContractFactory("RepToken", SIGNERS.CHARLIE);
    Coin1 = await ShitcoinFactory.deploy(InitialSupply); await Coin1.deployed();
    Coin2 = await ShitcoinFactory.deploy(InitialSupply); await Coin2.deployed();
    Coin3 = await ShitcoinFactory.deploy(InitialSupply); await Coin3.deployed();
    ADDRESSES["PaymentTokens"] = [Coin1.address, Coin2.address, Coin3.address]
    CONTRACT.PAYMENTTOKEN = await hre.ethers.getContractAt("RepToken", Coin1.address);
  })
  it("Should create a Project by Susanne (Sourcing Lead)", async function() {
    const SourceSusanne = CONTRACT.SOURCE.connect(SIGNERS.SUSANNE);
    const tx = await SourceSusanne.createProject(
                        SIGNERS.CHARLIE.address,  // client
                        SIGNERS.ALICE.address,   // arbiter
                        ADDRESSES["PaymentTokens"][0],   // first shit-coin
                        PARAMS.votingDuration)
    await tx.wait();
    let numberOfProjects = parseInt(ethers.utils.formatUnits(
                              await SourceSusanne.numberOfProjects(), 1));
    ADDRESSES["Projects"].push(await SourceSusanne.projects(numberOfProjects))
    CONTRACT.PROJECT = await hre.ethers.getContractAt("Project", ADDRESSES["Projects"][0])
    // console.log('The Project Status is: ', await CONTRACT.PROJECT.status())
    // console.log('The stating time of the project is: ', await CONTRACT.PROJECT.startingTime())

  });
  it("People vote on it. Bob: yes, Dave: no, Susanne: yes", async function(){
      tx = await CONTRACT.PROJECT.connect(SIGNERS.BOB).voteOnProject(true); await tx.wait();
      tx = await CONTRACT.PROJECT.connect(SIGNERS.DAVE).voteOnProject(false); await tx.wait();
      tx = await CONTRACT.PROJECT.connect(SIGNERS.SUSANNE).voteOnProject(true); await tx.wait();
  });
  it("Bob actually wants to change his vote, but he's too late. Nevertheless he triggers _registerVote() through his late decision.", async function(){
    console.log('\tThe project status before the elapse of the voting period is: ', await CONTRACT.PROJECT.attach(ADDRESSES["Projects"][0]).status())
    await later(PARAMS.votingDuration * 1000);
    projectBob = CONTRACT.PROJECT.connect(SIGNERS.BOB)
    tx = await projectBob.voteOnProject(false); await tx.wait();
    console.log('\tThe project status after the elapse of the voting period is: ', await CONTRACT.PROJECT.attach(ADDRESSES["Projects"][0]).status())
    let votes_pro = await projectBob.votes_pro();
    let votes_against = await projectBob.votes_against();
    console.log('\tThere have been ',
                votes_pro.toString(),
                ' votes for and ',
                votes_against.toString(),
                ' against the project.')
  });
  it("Susanne puts Dave to the project.", async function () {
    tx = await CONTRACT.PROJECT.connect(SIGNERS.SUSANNE).addTeamMember(SIGNERS.DAVE.address); await tx.wait();
  });
  it("Client locks shit-coins in the project.", async function (){
    tx = await CONTRACT.PAYMENTTOKEN
                  .attach(ADDRESSES["PaymentTokens"][0])
                  .connect(SIGNERS.CHARLIE)
                  .transfer(ADDRESSES["Projects"][0], PARAMS.firstMsAmount)
    await tx.wait()
    // balance of the project
    balanceOfProjectInShitCoins = await CONTRACT.PAYMENTTOKEN.balanceOf(ADDRESSES["Projects"][0])
    console.log('\tThe Project Contract has ',
                 balanceOfProjectInShitCoins.toString(),
                ' tokens locked up.')
  });
  it("Sourcing Lead Susanne wants to change Payment Method (should revert, because there are funds in the contract).", async function () {
    contractSusanne = CONTRACT.PROJECT.connect(SIGNERS.SUSANNE);
    console.log('\tThe payment Token before the update is: ', await contractSusanne.paymentToken());
    try {
      tx = await contractSusanne.changePaymentMethod(
        ADDRESSES["PaymentTokens"][1],
        1000000000);
      await tx.wait();
    } catch(err) {
      error = err.stackTrace['0'].sourceReference
      console.log("\tERROR in the following line: ", error.file.content.slice(error.range[0], error.range[1]))
      // sliced_err = err.slice(0,Math.min(err.length, 200))
      // console.log("Transaction didn't go through because: ", sliced_err)
    }
    console.log('\tThe payment Token before the update is: ', await contractSusanne.paymentToken());
    
  });
});
describe("Milestone has been achieved!", function () {
  it("Client is invoiced by Sourcing Lead", async function () {
    contractSusanne = CONTRACT.PROJECT.connect(SIGNERS.SUSANNE);
    outstandingInvoiceBefore = await contractSusanne.outstandingInvoice()
    console.log('\tBefore the Invoice there has been an outstanding amount of ', 
                outstandingInvoiceBefore.toString())
    tx = await contractSusanne.invoiceClient(PARAMS.invoicedMsAmount); await tx.wait();
    
    outstandingInvoiceAfter = await contractSusanne.outstandingInvoice()
    console.log('\tAfter the Invoice there is an outstanding amount of ', 
                outstandingInvoiceAfter.toString())
  });
  it("Client Charlie approves the Milestone plus a little tip", async function () {
    // balance of the project
    balanceOfProjectInShitCoinsBefore = await CONTRACT.PAYMENTTOKEN.balanceOf(ADDRESSES["Projects"][0])
    console.log('\tThe Project Contract has ',
    balanceOfProjectInShitCoinsBefore.toString(),
                ' tokens before the approval of the Client.')

    contractCharlie = CONTRACT.PROJECT.connect(SIGNERS.CHARLIE);
    tx = await contractCharlie.approveMilestone(PARAMS.clientApprovedMsAmount);

    balanceOfProjectInShitCoinsAfter = await CONTRACT.PAYMENTTOKEN.balanceOf(ADDRESSES["Projects"][0])
    balanceOfSourcingLeadAfter = await CONTRACT.PAYMENTTOKEN.balanceOf(SIGNERS.SUSANNE.address)
    
    console.log('\tThe Project Contract has ',
                balanceOfProjectInShitCoinsAfter.toString(),
                ' tokens after the approval of the Client.\n',
                '\tThe Sourcing Lead has ', balanceOfSourcingLeadAfter.toString(), 
                ' after the approval. Not more than before.')
    
  });
  it("Dave and Susanne submit their payment requests and approve all", async function (){
    contractProject = CONTRACT.PROJECT.attach(ADDRESSES["Projects"][0])
    // tx = await contractProject.connect(SIGNERS.SUSANNE).sumbitPaymentRequest(5); await tx.wait();
    // tx = await contractProject.connect(SIGNERS.DAVE).sumbitPaymentRequest(40); await tx.wait();
    // tx = await contractProject.connect(SIGNERS.SUSANNE).approveAll();  await tx.wait();
    // tx = await contractProject.connect(SIGNERS.DAVE).approveAll();  await tx.wait();
  })
})


function later(delay) {
  return new Promise(function(resolve) {
      setTimeout(resolve, delay);
  });
}
