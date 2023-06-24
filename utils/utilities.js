const { network, ethers } = require("hardhat");

const fundErc20 = async (contract, sender, recipient, amount, decimals) => {
  const FUND_AMOUNT = ethers.parseUnits(amount, decimals);
  const whale = await ethers.getSigner(sender);
  const contractSigner = contract.connect(whale);
  await contractSigner.transfer(recipient, FUND_AMOUNT);
};

const impersonateFundErc20 = async (contract, sender, recipient, amount, decimals) => {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [sender],
  });

  // Fund contract
  await fundErc20(contract, sender, recipient, amount, decimals);

  await network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: [sender],
  });
};

module.exports = {
  impersonateFundErc20: impersonateFundErc20,
};
