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

contract UniswapCrossSwap {
    using SafeERC20 for IERC20;

    // Factory and Router Addresses
    address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address private constant SUSHI_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address private constant SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    // Token Addresses
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    
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
        uint256 _amountIn,
        address factory,
        address router
    ) private returns (uint256) {
        address pair = IUniswapV2Factory(factory).getPair(
            _fromToken,
            _toToken
        );
        require(pair != address(0), "Pool doesn't exist");

        // Calculate AmountOut
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        uint256 amountRequired = IUniswapV2Router01(router)
            .getAmountsOut(_amountIn, path)[1];

        // Perform Arbitrage - Swap to another token
        uint amountReceived = IUniswapV2Router01(router)
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
    
    function startCrossSwap(address _tokenBorrow, uint256 _amount) external {
        IERC20(WETH).forceApprove(UNISWAP_ROUTER, MAX_INT);
        IERC20(USDC).forceApprove(UNISWAP_ROUTER, MAX_INT);
        IERC20(LINK).forceApprove(UNISWAP_ROUTER, MAX_INT);

        IERC20(WETH).forceApprove(SUSHI_ROUTER, MAX_INT);
        IERC20(USDC).forceApprove(SUSHI_ROUTER, MAX_INT);
        IERC20(LINK).forceApprove(SUSHI_ROUTER, MAX_INT);
       
        
        // Get the Factory pair address to combined tokens
        address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(
            _tokenBorrow,
            WETH
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

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        // Ensure this request came from the contract
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

         address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(
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


        // Calculate loanAmount
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        // Trade 1
        uint256 trade1Acquired = placeTrade(USDC, LINK, loanAmount, UNISWAP_FACTORY, UNISWAP_ROUTER);

        // Trade 2
        uint256 trade2Acquired = placeTrade(LINK, USDC, trade1Acquired, SUSHI_FACTORY, SUSHI_ROUTER);
       

        // Check profitable FlashLoan
        bool profCheck = checkProfitableFlashSwap(amountToRepay, trade2Acquired);
        require(profCheck, "FlashCrossSwap not profitable");
        
        // Pay myself
        IERC20(USDC).transfer(myAddress,trade2Acquired - amountToRepay);
        
        // Pay loan back
        IERC20(tokenBorrow).transfer(pair, amountToRepay);
    }
}
