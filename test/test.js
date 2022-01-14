// const { expect } = require("chai");
const { ethers, network } = require("hardhat");

const SIGNERS = {
  ALICE: null,
  BOB: null,
  CHARLIE: null,
  DANIEL: null
}

CONTRACTS = {
  SOURCE: null,
  PROJECT: null,
  REPTOKEN: null
}

ADDRESSES = {
}

describe("Deployment", function () {
  it("Should store the signers and contract instances.", async function() {
    const accounts = await ethers.getSigners()
    SIGNERS.ALICE=accounts[0]  // Arbiter
    SIGNERS.BOB=accounts[1]  // 
    SIGNERS.CHARLIE=accounts[2]  // Client
    SIGNERS.DAVE=accounts[3]  // Developer
    SIGNERS.SUSANNE=accounts[4]  // Sourcing Lead

    CONTRACTS.SOURCE = await ethers.getContractFactory("Source");
    CONTRACTS.PROJECT = await ethers.getContractFactory("Project");
    CONTRACTS.REPTOKEN = await ethers.getContractFactory("RepToken");
  });
  it("Should deploy the source contract by Alice.", async function () {
    const SourceBob = CONTRACTS.SOURCE.connect(SIGNERS.BOB)
    const source = await SourceBob.deploy();
    tx = await source.deployed();
    console.log('Transaction was signed by: ', tx.signer.address)
    console.log('Deployed to: ', source.address)
    console.log('Deployed by: ', SIGNERS.BOB.address)
    // // wait until the transaction is mined
    // await setGreetingTx.wait();

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
  it("Should create a Project by Dave", async function() {
    const SourceDave = CONTRACTS.SOURCE.connect(SIGNERS.Dave)
  });
});
