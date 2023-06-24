require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.18",
      },
      {
        version: "0.5.0",
      },
      {
        version: "0.6.2",
      },
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/0HrHlhFOcL8RCj8WQ0P_JjrzcLRAWoe4",
      },
    },
    testnet: {
      url: "https://eth-goerli.g.alchemy.com/v2/efmgfFKyXsy0pZocmybf8uTxx4dPHUm5",
      chainId: 5,
      accounts: [
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ], // Private key to deploy
    },
    mainnet: {
      url: "https://eth-mainnet.g.alchemy.com/v2/0HrHlhFOcL8RCj8WQ0P_JjrzcLRAWoe4",
      chainId: 1
    },
  },
};
