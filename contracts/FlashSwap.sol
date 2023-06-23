// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "hardhat/console.sol";

// Uniswap libraries and interfaces
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract PancakeswapFlashSwap {
    using SafeERC20 for IERC20;

    // Factory and Router Addresses
    address private constant PANCAKE_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKE_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // Token Addresses
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address private constant DOT = 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402;
    address private constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address private constant ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

    // Trade variables
    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT = 2 ** 256 - 1;

    //FUND SMART CONTRACT
    // Provide a function to fund the contract
    function fundFlashSwapContract(
        address _owner,
        address _token,
        uint256 _amount
    ) public {
        IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    // GET CONTRACT BALANCE
    // Allow to getBalance of a token
    function getBalanceOfToken(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    // PLACE TRADE
    function placeTrade(
        address _fromToken,
        address _toToken,
        uint256 _amountIn
    ) private returns (uint256) {
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            _fromToken,
            _toToken
        );
        require(pair != address(0), "Pool doesn't exist");

        // Calculate AmountOut
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        uint256 amountRequired = IUniswapV2Router01(PANCAKE_ROUTER)
            .getAmountsOut(_amountIn, path)[1];

        // Perform Arbitrage - Swap to another token
        uint amountReceived = IUniswapV2Router01(PANCAKE_ROUTER)
            .swapExactTokensForTokens(
                _amountIn,
                amountRequired,
                path,
                address(this),
                deadline
            )[1];

        require(amountReceived > 0, "Aborted Tx: Trade returned zero");
        return amountReceived;
    }

    function checkProfitableFlashSwap(
        uint256 _input,
        uint256 _output
    ) private pure returns (bool) {
        return _output > _input;
    }

    // INITIATE ARBITRAGE
    function startArbitrage(address _tokenBorrow, uint256 _amount) external {
        IERC20(WBNB).forceApprove(PANCAKE_ROUTER, MAX_INT);
        IERC20(BUSD).forceApprove(PANCAKE_ROUTER, MAX_INT);
        IERC20(CAKE).forceApprove(PANCAKE_ROUTER, MAX_INT);
        IERC20(USDT).forceApprove(PANCAKE_ROUTER, MAX_INT);
        IERC20(DOT).forceApprove(PANCAKE_ROUTER, MAX_INT);
        IERC20(BTCB).forceApprove(PANCAKE_ROUTER, MAX_INT);
        IERC20(ETH).forceApprove(PANCAKE_ROUTER, MAX_INT);

        // Get the Factory pair address to combined tokens
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            _tokenBorrow,
            WBNB
        );

        require(pair != address(0), "Pool doesn't exist");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        // Passing data as bytes so that the 'swap' function knwows it is a flashloan
        bytes memory data = abi.encode(_tokenBorrow, _amount, msg.sender);

        // Execute the initial swap to get the loan
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        // Ensure this request came from the contract
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            token0,
            token1
        );
        require(pair == msg.sender, "The sender needs to match the pair");
        require(
            _sender == address(this),
            "The sender should match this contract"
        );

        // Decode data to calculate the repayment
        (address tokenBorrow, uint256 amount, address myAddress) = abi.decode(
            _data,
            (address, uint256, address)
        );

        // Calculate the amount to repay
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        // DO ARBITRAGE
        // Calculate loanAmount
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        // Place trades
        uint256 trade1AcquiredCoin = placeTrade(BUSD, DOT, loanAmount);
        uint256 trade2AcquiredCoin = placeTrade(DOT, CAKE, trade1AcquiredCoin);
        uint256 trade3AcquiredCoin = placeTrade(CAKE, BUSD, trade2AcquiredCoin);

        // Check profitable FlashLoan
        bool profCheck = checkProfitableFlashSwap(
            amountToRepay,
            trade3AcquiredCoin
        );
        require(profCheck, "Arbitrage not profitable");

        // Pay myself
        IERC20(BUSD).transfer(myAddress, trade3AcquiredCoin - amountToRepay);

        // Pay loan back
        IERC20(tokenBorrow).transfer(pair, amountToRepay);
    }
}
