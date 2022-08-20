// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from './FollowValidatorFollowModuleBase.sol';
import {IFollowModule} from '../../../interfaces/IFollowModule.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title SingleERC1155GateFollowModule
 * @author Nezzar Kefif
 * @dev Allows holders of a certain ERC1155 NFT to follow
 */
contract SingleERC1155GateFollowModule is IFollowModule, FollowValidatorFollowModuleBase {
    struct ERC1155GateConfig {
        address tokenAddress;
        uint256 tokenId;
        uint256 minAmount;
        bool transferable;
    }

    mapping(uint256 => ERC1155GateConfig) public nftGateByProfile;

    constructor(address hub) ModuleBase(hub) {}

    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        override
        onlyHub
        returns (bytes memory)
    {
        (address tokenAddress, uint256 tokenId, uint256 minAmount, bool transferable) = abi.decode(
            data,
            (address, uint256, uint256, bool)
        );

        nftGateByProfile[profileId] = ERC1155GateConfig(
            tokenAddress,
            tokenId,
            minAmount,
            transferable
        );

        return data;
    }

    function processFollow(
        address follower,
        uint256 profileId,
        bytes calldata // data
    ) external view override {
        _checkERC1155NftOwnership(follower, profileId);
    }

    function followModuleTransferHook(
        uint256 profileId,
        address from,
        address to,
        uint256 followNFTTokenId
    ) external view override {
        require(nftGateByProfile[profileId].transferable, 'FOLLOW_NON_TRANSFERABLE');
        _checkERC1155NftOwnership(to, profileId);
    }

    function updateGateConfig(
        uint256 profileId,
        address tokenAddress,
        uint256 tokenId,
        uint256 minAmount,
        bool transferable
    ) external {
        require(IERC721(HUB).ownerOf(profileId) == msg.sender, 'ONLY_PROFILE_OWNER');

        nftGateByProfile[profileId] = ERC1155GateConfig(
            tokenAddress,
            tokenId,
            minAmount,
            transferable
        );
    }

    function _checkERC1155NftOwnership(address _user, uint256 _profileId) private view {
        ERC1155GateConfig memory gateConfig = nftGateByProfile[_profileId];

        if (gateConfig.tokenAddress != address(0)) {
            require(
                IERC1155(gateConfig.tokenAddress).balanceOf(_user, gateConfig.tokenId) >=
                    gateConfig.minAmount,
                'INSUFFICIENT_NFT_BALANCE'
            );
        }
    }
}
