require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config();

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
 const { alicepk, bobpk, sampk, ETHERSCAN_API_KEY, LOCALHOST, LOCALPORT, rinkebyurl } = process.env;
module.exports = {
  solidity: "0.8.7",
  defaultNetwork: "rinkeby",
  networks:{
    localhost: {
      url: LOCALHOST + ":" + LOCALPORT,
      accounts: [alicepk, bobpk, sampk]
    },
    rinkeby: {
      url: rinkebyurl,
      accounts: [alicepk, bobpk, sampk]
    },
    hardhat: {
      mining: {}
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
};
