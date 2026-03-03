// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple ERC-20 for testing. Mint freely.
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

/**
 * @title MockFeeToken
 * @notice ERC-20 with a 10% transfer tax (fee-on-transfer).
 *         Used to test the balance-before/after pattern.
 */
contract MockFeeToken is ERC20 {
    uint256 public constant TAX_BPS = 1000; // 10%

    constructor() ERC20("FeeToken", "FEE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 tax = (amount * TAX_BPS) / 10000;
        uint256 afterTax = amount - tax;
        super._transfer(from, to, afterTax);
        // Tax is simply destroyed (not minted to anyone)
        if (tax > 0) {
            super._transfer(from, address(0xdead), tax);
        }
    }
}
