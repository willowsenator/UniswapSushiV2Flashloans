const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const { impersonateFundErc20 } = require("../utils/utilities");

const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");
const provider = ethers.provider;

const BUSD_WHALE = "0xf977814e90da44bfa03b6295a0616a897441acec";
const WBNB = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
const CAKE = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82";
const USDT = "0x55d398326f99059fF775485246999027B3197955";
const DOT = "0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402";
const BTCB = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
const ETH = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8";

describe("FlashSwap contract", () => {
  let FLASHSWAP,
    BORROW_AMOUNT,
    FUND_AMOUNT,
    initialFundingHuman,
    txtArbitrage,
    gasUsedUSD;
  const DECIMALS = 18;

  const BASE_TOKEN_ADDRESS = BUSD;
  tokenBase = new ethers.Contract(BASE_TOKEN_ADDRESS, abi, provider);

  beforeEach(async () => {
    [owner] = await ethers.getSigners();

    const whale_balance = await provider.getBalance(BUSD_WHALE);
    expect(whale_balance).not.eq("0");

    // Deploy smart Contract
    FLASHSWAP = await ethers.deployContract("PancakeswapFlashSwap");
    await FLASHSWAP.waitForDeployment();

    // Configure borrowing
    const borrowInHuman = "1";
    BORROW_AMOUNT = ethers.parseUnits(borrowInHuman, DECIMALS);

    // Configure Funding -- FOR TESTING
    initialFundingHuman = "100";
    FUND_AMOUNT = ethers.parseUnits(initialFundingHuman, DECIMALS);

    // Fund our contract -- FOR TESTING

    await impersonateFundErc20(
      tokenBase,
      BUSD_WHALE,
      FLASHSWAP.target,
      initialFundingHuman
    );
  });

  describe("Arbitrage Execution", () => {
    it("Ensure contract is funded", async () => {
      const flashswapBalance = await FLASHSWAP.getBalanceOfToken(
        BASE_TOKEN_ADDRESS
      );
      const flashswapBalanceInHuman = ethers.formatUnits(
        flashswapBalance,
        DECIMALS
      );

      expect(Number(flashswapBalanceInHuman)).eq(Number(initialFundingHuman));
    });

    it("Start arbitrage", async () => {
      txtArbitrage = await FLASHSWAP.startArbitrage(
        BASE_TOKEN_ADDRESS,
        BORROW_AMOUNT
      );
      assert(txtArbitrage);

      // Print balances
      const contractBUSDBalance = await FLASHSWAP.getBalanceOfToken(BUSD);
      const formattedBUSDBalance = ethers.formatUnits(
        contractBUSDBalance,
        DECIMALS
      );

      console.log("Balance of BUSD: ", formattedBUSDBalance);

      const contractDOTBalance = await FLASHSWAP.getBalanceOfToken(DOT);
      const formattedDOTBalance = ethers.formatUnits(
        contractDOTBalance,
        DECIMALS
      );

      console.log("Balance of DOT: ", formattedDOTBalance);

      const contractCAKEBalance = await FLASHSWAP.getBalanceOfToken(CAKE);
      const formattedCAKEBalance = ethers.formatUnits(
        contractCAKEBalance,
        DECIMALS
      );

      console.log("Balance of CAKE: ", formattedCAKEBalance);
    });
  });
});
