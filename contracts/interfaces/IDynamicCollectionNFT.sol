// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

interface IDynamicCollectionNFT {
    function initialize(
        uint256 profileId,
        uint256 pubId,
        string memory baseURI__,
        uint256 maxSupply,
        string calldata name,
        string calldata symbol
    ) external;

    /**
     * @notice Mints a collect NFT to the specified address. This can only be called by the hub, and is called
     * upon collection.
     *
     * @param to The address to mint the NFT to.
     *
     * @return uint256 An interger representing the minted token ID.
     */
    function mint(address to) external returns (uint256);

    /**
     * @notice Returns the source publication pointer mapped to this collect NFT.
     *
     * @return tuple First the profile ID uint256, and second the pubId uint256.
     */
    function getSourcePublicationPointer() external view returns (uint256, uint256);
}
