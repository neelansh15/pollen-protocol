// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

/**
    Sample NFT for testing
 */
contract MyNFT is ERC721 {
    uint256 public tokenId;

    constructor() ERC721('MyNFT', 'MNFT') {}

    function mint() public {
        _safeMint(msg.sender, ++tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return
            'https://lh3.googleusercontent.com/XxhM2mhlRSOYwPKl69KBj12LFw4T3xkD2JLvofwHZT32YT9ke992adeK9Ajx6zy9n7tY8OLN48DtCxa2a9vzSTrOxS84M05FfDHFL_Y=w600';
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return _baseURI();
    }
}
