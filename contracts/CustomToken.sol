// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomToken is ERC20, Ownable {

    constructor(
        string memory name, 
        string memory symbol, 
        uint256 initialSupply
    ) ERC20(name, symbol){
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Mint new tokens. Only the owner can call this function.
     * @param account Address to receive the minted tokens.
     * @param amount Amount of tokens to be minted.
     */
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    /**
     * @dev Burn tokens from an account. Only the owner can call this function.
     * @param account Address whose tokens will be burned.
     * @param amount Amount of tokens to be burned.
     */
    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
