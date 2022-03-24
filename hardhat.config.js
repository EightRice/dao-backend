require("@nomiclabs/hardhat-waffle");
require('dotenv').config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

// console.log(process.env(RINKEBY_RPC_ENDPOINT_INFURA))
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.7",
  defaultNetwork: "localhost",
  networks:{
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    rinkeby: {
      url: process.env["RINKEBY_RPC_ENDPOINT_INFURA"],
      accounts: [process.env["ALICE_PRIVATEKEY"], process.env["BOB_PRIVATEKEY"], process.env["CHARLIE_PRIVATEKEY"]]
    },
    hardhat: {
      mining: {
        // auto: false,
        // interval: 0
      }
    }
  }
};
