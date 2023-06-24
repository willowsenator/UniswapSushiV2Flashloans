const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const { impersonateFundErc20 } = require("../utils/utilities");

const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");
const provider = ethers.provider;

const USDC_WHALE = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const LINK = "0x514910771AF9Ca656af840dff83E8264EcF986CA";

describe("FlashSwap contract", () => {
  let FLASHSWAP,
    BORROW_AMOUNT,
    FUND_AMOUNT,
    initialFundingHuman,
    txFlashCrossSwap;
  const DECIMALS_STABLE_COIN = 6;
  const DECIMALS_TOKEN = 18;

  const BASE_TOKEN_ADDRESS = USDC;
  tokenBase = new ethers.Contract(BASE_TOKEN_ADDRESS, abi, provider);

  beforeEach(async () => {
    [owner] = await ethers.getSigners();

    const whale_balance = await provider.getBalance(USDC_WHALE);
    expect(whale_balance).not.eq("0");

    // Deploy smart Contract
    FLASHSWAP = await ethers.deployContract("UniswapCrossSwap");
    await FLASHSWAP.waitForDeployment();

    // Configure borrowing
    const borrowInHuman = "1";
    BORROW_AMOUNT = ethers.parseUnits(borrowInHuman, DECIMALS_STABLE_COIN);

    // Configure Funding -- FOR TESTING
    initialFundingHuman = "100";
    FUND_AMOUNT = ethers.parseUnits(initialFundingHuman, DECIMALS_STABLE_COIN);

    // Fund our contract -- FOR TESTING

    await impersonateFundErc20(
      tokenBase,
      USDC_WHALE,
      FLASHSWAP.target,
      initialFundingHuman,
      DECIMALS_STABLE_COIN
    );
  });

  describe("FlashCrossSwap Execution", () => {
    it("Ensure contract is funded", async () => {
      const flashswapBalance = await FLASHSWAP.getBalanceOfToken(
        BASE_TOKEN_ADDRESS
      );
      const flashswapBalanceInHuman = ethers.formatUnits(
        flashswapBalance,
        DECIMALS_STABLE_COIN
      );

      expect(Number(flashswapBalanceInHuman)).eq(Number(initialFundingHuman));
    });

    it("Start cross Swap", async () => {
      txFlashCrossSwap = await FLASHSWAP.startCrossSwap(
        BASE_TOKEN_ADDRESS,
        BORROW_AMOUNT
      );
      assert(txFlashCrossSwap);

      // Print balances
      const contractUSDCBalance = await FLASHSWAP.getBalanceOfToken(USDC);
      const formattedUSDCBalance = ethers.formatUnits(
        contractUSDCBalance,
        DECIMALS_STABLE_COIN
      );

      console.log("Balance of USDC: ", formattedUSDCBalance);

      const contractLINKBalance = await FLASHSWAP.getBalanceOfToken(LINK);
      const formattedLINKBalance = ethers.formatUnits(
        contractLINKBalance,
        DECIMALS_TOKEN
      );

      console.log("Balance of LINK: ", formattedLINKBalance);

    });

    it("Gas used Output", async()=>{
      const txReceipt = await provider.getTransactionReceipt(txFlashCrossSwap.hash);
      const gasPrice = txReceipt.gasPrice;
      const gasUsed = txReceipt.gasUsed;
      const gasUsedETH = gasPrice * gasUsed;

      console.log("TOTAL GAS USD: ", ethers.formatEther(gasUsedETH.toString()) * 1888);
    });
  });
});
