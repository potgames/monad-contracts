require("@nomiclabs/hardhat-ganache");
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("@nomicfoundation/hardhat-chai-matchers");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

module.exports = {
  defaultNetwork: "ganache",
  solidity: {
    compilers: [
      {
        version: "0.5.16",
      },
      {
        version: "0.8.0",
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
      {
        version: "0.8.23",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
    ],
  },

  networks: {
    ganache: {
      url: "http://ganache:8545",
      accounts: {
        mnemonic:
          "tail actress very wool broom rule frequent ocean nice cricket extra snap",
        path: " m/44'/60'/0'/0/",
        initialIndex: 0,
        count: 20,
      },
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [`${process.env.PRIVATE_KEY}`],
      chainId: 11155111,
    },
    monadDevnet: {
      url: process.env.MONAD_RPC_URL,
      accounts: [`${process.env.PRIVATE_KEY}`],
      chainId: 10143,
      gasPrice: "auto"
    }
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY,
      monadDevnet: 'empty'
    },
    customChains: [
      {
        network: "monadDevnet",
        chainId: 10143,
        urls: {
          apiURL: "https://testnet.monadexplorer.com/api",
          browserURL: "https://testnet.monadexplorer.com"
        }
      }
    ]
  },
  sourcify: {
    enabled: true,
    apiUrl: "https://sourcify-api-monad.blockvision.org",
    browserUrl: "https://testnet.monadexplorer.com"
  },
  etherscan: {
    enabled: false,
  },
};
