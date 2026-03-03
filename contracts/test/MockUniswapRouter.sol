// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockUniswapV2Router
 * @notice Simulates Uniswap V2 Router for testing protocol fee swaps.
 *         Accepts input token, "swaps" by minting output token at 1:1 rate.
 *         The GROK output token must be pre-funded to this contract.
 */
contract MockUniswapV2Router {
    address public immutable WETH_ADDR;
    bool public shouldFail;

    constructor(address _weth) {
        WETH_ADDR = _weth;
    }

    function WETH() external view returns (address) {
        return WETH_ADDR;
    }

    function setShouldFail(bool _fail) external {
        shouldFail = _fail;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 /* amountOutMin */,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external returns (uint256[] memory amounts) {
        require(!shouldFail, "MockRouter: swap failed");

        address inputToken = path[0];
        address outputToken = path[path.length - 1];

        // Take input tokens from caller (the Arena contract)
        IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn);

        // Send a fixed output amount (simulates swap at some rate)
        // Using a small fixed amount avoids decimal mismatch issues
        uint256 outputAmount = 1000 * 1e9; // 1000 GROK (9 decimals)
        uint256 available = IERC20(outputToken).balanceOf(address(this));
        if (outputAmount > available) outputAmount = available;
        if (outputAmount > 0) IERC20(outputToken).transfer(to, outputAmount);

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = outputAmount;
    }
}
