const hre = require("hardhat");
const fs = require('fs');
const csv = require('csv-parser')


const SIGNERS = {
    ALICE: null,
    BOB: null,
    CHARLIE: null
  }
async function loadSigners () {
    let allSigners = await hre.ethers.getSigners()
    SIGNERS.ALICE = allSigners[0]
    SIGNERS.BOB = allSigners[1]
    SIGNERS.CHARLIE = allSigners[2]
}

let tx;
let receipt;
let oneETH = hre.ethers.utils.parseEther("1.0");
let transferAmount = oneETH.mul(100000)
let payrollAmount = oneETH.mul(420);

async function checkInternal(){
    await loadSigners();

    let rawdata = fs.readFileSync(`info/${hre.network.name}/contracts.json`);
    let contractAddresses = JSON.parse(rawdata);
    let firstInternalProjectAddress = contractAddresses["firstInternalProject"]
    let sourceAddress = contractAddresses["Source"]

    let internalProject = await hre.ethers.getContractAt("InternalProject", firstInternalProjectAddress, SIGNERS.ALICE);
    let source = await hre.ethers.getContractAt("Source", sourceAddress, SIGNERS.ALICE);
    let paymentTokenAddress = await source.defaultPaymentToken();
    let defaultPaymentToken = await hre.ethers.getContractAt("PaymentToken", paymentTokenAddress, SIGNERS.ALICE);

    console.log(`The default Payment Token is deployed at ${defaultPaymentToken.address}.`)

    let thisCyclesRequestedAmount = hre.ethers.utils.formatEther(await internalProject.getThisCyclesRequestedAmount())
    let remainingFunds = hre.ethers.utils.formatEther(await internalProject.remainingFunds())
    let allowedSpendingsPerPaymentCycle = hre.ethers.utils.formatEther(await internalProject.allowedSpendingsPerPaymentCycle())
    console.log(`
                 The requested amounts are ${remainingFunds}. 
                 This cycles allowed spendings are ${allowedSpendingsPerPaymentCycle}.
                 No amount has been requested yet, so this cylce's requested amounts are ${thisCyclesRequestedAmount}`)

    let teamLead = await internalProject.teamLead();
    console.log('\nteamLead', teamLead)
    // console.log('SIGNERS', SIGNERS.ALICE.address, SIGNERS.BOB.address, SIGNERS.CHARLIE.address)
    
    if ((await defaultPaymentToken.balanceOf(SIGNERS.ALICE.address)) < transferAmount){
        tx = await defaultPaymentToken.connect(SIGNERS.ALICE).freeMint(transferAmount)
        receipt = await tx.wait()
    }
    tx = await defaultPaymentToken.connect(SIGNERS.ALICE).transfer(source.address, transferAmount)
    receipt = await tx.wait()
    let sourceBalance = hre.ethers.utils.formatEther(await defaultPaymentToken.balanceOf(source.address))
    let CharliesAmountBefore = await defaultPaymentToken.balanceOf(SIGNERS.CHARLIE.address)
    tx = await internalProject.connect(SIGNERS.ALICE).submitPayrollRoster(
        [SIGNERS.CHARLIE.address],
        [payrollAmount])
    receipt = await tx.wait();
    console.log(CharliesAmountBefore)
    let remainingFundsAfter = hre.ethers.utils.formatEther(await internalProject.remainingFunds())
    let conversion = hre.ethers.utils.formatEther(await source.getConversionRate(paymentTokenAddress))
    let requesteThisCycle = hre.ethers.utils.formatEther(await source.getThisCyclesTotalRequested())
    console.log('conversion', conversion)
    console.log('requesteThisCycle', requesteThisCycle)
    tx = await source.connect(SIGNERS.ALICE).payout()
    receipt = await tx.wait();
    let CharliesAmountAfter = await defaultPaymentToken.balanceOf(SIGNERS.CHARLIE.address)
    console.log(`
            The remaining funds are ${remainingFundsAfter}.
            The source holds ${sourceBalance} paymentTokens.
            Charlies balance before payout is ${CharliesAmountBefore}.
            Charlies balance after payout is ${CharliesAmountAfter}.`)

    // console.log('receipt', receipt)

}


checkInternal()