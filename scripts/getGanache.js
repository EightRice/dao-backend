require('dotenv').config();
// const exec = require("child_process").exec;

// function execShellCommand(cmd) {
//   const exec = require("child_process").exec;
//   return new Promise((resolve, reject) => {
//     exec(cmd, { maxBuffer: 1024 * 500 }, (error, stdout, stderr) => {
//       if (error) {
//         console.warn(error);
//       } else if (stdout) {
//         console.log(stdout); 
//       } else {
//         console.log(stderr);
//       }
//       resolve(stdout ? true : false);
//     });
//   });
// }

function getGanacheCommand () {
    let gasLimit = "80000000"
    let port = process.env["localport"]
    let pks = [process.env["alicepk"], process.env["bobpk"], process.env["sampk"]]
    // let addresses = new Array()
    let accounts = ''
    let alotta = '100000000000000000000'  // 100 Eth
    for (let i=0; i<pks.length; i++) {
        // let wl = new hre.ethers.Wallet(pks[i])
        // addresses.push(wl.address)
        accounts += `--account="0x${pks[i]},${alotta}" `
    }
    return `ganache-cli -l ${gasLimit} -p ${port} ${accounts}`
}

console.log(getGanacheCommand())