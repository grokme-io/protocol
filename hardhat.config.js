require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-chai-matchers");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: { optimizer: { enabled: true, runs: 200 }, viaIR: true },
      },
      {
        version: "0.8.20",
        settings: { optimizer: { enabled: true, runs: 200 }, viaIR: true },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
