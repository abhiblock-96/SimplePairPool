//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract TokenA is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    error OnlyOwnerCanBurnTokens();

    constructor() ERC20("DAICOIN", "DAI") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external {
        if (msg.sender != account) revert OnlyOwnerCanBurnTokens();
        _burn(account, value);
    }
}

contract TokenB is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    error OnlyOwnerCanBurnTokens();

    constructor() ERC20("USDCCOIN", "USDC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external {
        if (msg.sender != account) revert OnlyOwnerCanBurnTokens();
        _burn(account, value);
    }
}
