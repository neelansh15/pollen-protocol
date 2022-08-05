// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
    Sample Token for testing
 */
contract Token is ERC20 {
    using SafeERC20 for ERC20;

    uint256 public tokenId;

    constructor() ERC20('TestToken', 'TT') {}

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
