// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';

contract MyERC1155 is ERC1155 {
    constructor()
        ERC1155(
            'https://lh3.googleusercontent.com/XxhM2mhlRSOYwPKl69KBj12LFw4T3xkD2JLvofwHZT32YT9ke992adeK9Ajx6zy9n7tY8OLN48DtCxa2a9vzSTrOxS84M05FfDHFL_Y=w600'
        )
    {}

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        _mintBatch(to, ids, amounts, data);
    }
}
