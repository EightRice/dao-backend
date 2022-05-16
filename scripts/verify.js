const { exec } = require('child_process');
const fs = require('fs');
const hre = require('hardhat');


function execShellCommand(cmd) {
    return new Promise((resolve, reject) => {
      exec(cmd, { maxBuffer: 1024 * 500 }, (error, stdout, stderr) => {
        if (error) {
          console.warn(error);
        } else if (stdout) {
          console.log(stdout); 
        } else {
          console.log(stderr);
        }
        resolve(stdout ? true : false);
      });
    });
  }

function saveDeploymentArgumentsToFile() {

    let exportFile = ''

    let rawdata = fs.readFileSync(`info/${hre.network.name}/deployment-variables.json`);
    let deploymentVariables = JSON.parse(rawdata);
    deploymentVariablesList = Object.keys(deploymentVariables)

    for (let i=0; i<deploymentVariablesList.length; i++){
        contractAddress = deploymentVariablesList[i]
        let variables = deploymentVariables[contractAddress]["variables"];
        exportFile = 'module.exports = [\n'
        for (let j=0; j<variables.length; j++ ){
            exportFile += "\t" + variables[j] + ",\n"
        }
        exportFile += ']'
        // console.log(exportFile)
        let fileName = "deploy-vars-" + deploymentVariables[contractAddress]["name"] + ".js"
        fs.writeFileSync(`scripts/verification/${hre.network.name}/${fileName}`, exportFile)
    }

}


// verify on Etherscan
async function verifyThisContract(address) {
    let rawdata = fs.readFileSync(`info/${hre.network.name}/deployment-variables.json`);
    let deploymentVariables = JSON.parse(rawdata);
    deploymentVariablesList = Object.keys(deploymentVariables)
    let fileName = "deploy-vars-" + deploymentVariables[address]["name"] + ".js"
    let filePath = `scripts/verification/${hre.network.name}/${fileName}`
    let fullyQualifiedContractName = deploymentVariables[deploymentAddress]["contract-path"] + ':' + deploymentVariables[deploymentAddress]["name"]
    let arguments = ` --network ${hre.network.name} --contract ${fullyQualifiedContractName} --constructor-args ${filePath} ${address}`  
    cmd = "npx hardhat verify " + arguments;
    console.log(cmd) 
    // await execShellCommand(cmd);
}

async function verifyAllContracts() {
    let rawdata = fs.readFileSync(`info/${hre.network.name}/deployment-variables.json`);
    let deploymentVariables = JSON.parse(rawdata);
    deploymentVariablesList = Object.keys(deploymentVariables)
    for (let i=0; i<deploymentVariablesList.length; i++){
        let deploymentAddress = deploymentVariablesList[i]
        let fileName = "deploy-vars-" + deploymentVariables[deploymentAddress]["name"] + ".js"
        let filePath = `scripts/verification/${hre.network.name}/${fileName}`
        let fullyQualifiedContractName = deploymentVariables[deploymentAddress]["contract-path"] + ':' + deploymentVariables[deploymentAddress]["name"]
        let arguments = ` --network ${hre.network.name} --contract ${fullyQualifiedContractName} --constructor-args ${filePath} ${deploymentAddress}` 
        cmd = "npx hardhat verify " + arguments;
        console.log(cmd) 
        // await execShellCommand(cmd);
    }

}

// verifyThisContract("0x31a599Fc8C2ee48b096772fF38C207603e9024F4")
saveDeploymentArgumentsToFile()
verifyAllContracts()

