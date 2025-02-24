import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@openzeppelin/hardhat-upgrades";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.23",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      url: process.env.HTTP_RPC_URL_SEPOLIA!,
      accounts: [process.env.PRIVATE_KEY_SEPOLIA!],
    },
    spotlightSepolia: {
      url: process.env.HTTP_RPC_URL_SPOTLIGHT_SEPOLIA!,
      accounts: [process.env.PRIVATE_KEY_SPOTLIGHT_SEPOLIA!],
    },
    spotlight: {
      url: process.env.HTTP_RPC_URL_SPOTLIGHT_MAINNET!,
      accounts: [process.env.PRIVATE_KEY_SPOTLIGHT_MAINNET!],
    },
    baseSepolia: {
      url: process.env.HTTP_RPC_URL_BASE_SEPOLIA!,
      accounts: [process.env.PRIVATE_KEY_BASE_SEPOLIA!],
    },
    baseMainnet: {
      url: process.env.HTTP_RPC_URL_BASE_MAINNET!,
      accounts: [process.env.PRIVATE_KEY_BASE_MAINNET!],
    },
    fork: {
      url: process.env.HTTP_RPC_URL_BASE_SEPOLIA!,
      accounts: [process.env.PRIVATE_KEY_BASE_SEPOLIA!],
    },
  },
  sourcify: {
    enabled: true
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.SEPOLIA_SCAN_API_KEY!,
      baseSepolia: process.env.SEPOLIA_BASE_SCAN_API_KEY!,
      base: process.env.MAINNET_BASE_SCAN_API_KEY!,
      spotlightSepolia: process.env.SPOTLIGHT_SEPOLIA_BASE_SCAN_API_KEY!,
      spotlight: process.env.SPOTLIGHT_MAINNET_BASE_SCAN_API_KEY!,
    },
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org/",
        },
      },
      {
        network: "spotlightSepolia",
        chainId: 10058112,
        urls: {
          apiURL: "https://spotlight-sepolia.explorer.alchemy.com/api",
          browserURL: "https://spotlight-sepolia.explorer.alchemy.com/",
        },
      },
      {
        network: "spotlight",
        chainId: 10058111,
        urls: {
          apiURL: "https://spotlight-mainnet.explorer.alchemy.com/api",
          browserURL: "https://spotlight-mainnet.explorer.alchemy.com/",
        },
      },
    ],
  },
};

export default config;
