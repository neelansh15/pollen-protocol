// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {ModuleBase} from '../ModuleBase.sol';
import {Errors} from '../../../libraries/Errors.sol';

import {FollowValidatorFollowModuleBase} from './FollowValidatorFollowModuleBase.sol';
import {IFollowModule} from '../../../interfaces/IFollowModule.sol';

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title MultipleAndERC721GateFollowModule
 * @author Neelansh Mathur
 * @dev A follow module that allows users to follow only if they hold all of the NFTs set by the profile owner.
 **/
contract MultipleAndERC721GateFollowModule is IFollowModule, FollowValidatorFollowModuleBase {
    mapping(uint256 => address[]) public nftsByProfile;

    constructor(address hub) ModuleBase(hub) {}

    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        override
        onlyHub
        returns (bytes memory)
    {
        nftsByProfile[profileId] = abi.decode(data, (address[]));
        return data;
    }

    function processFollow(
        address follower,
        uint256 profileId,
        bytes calldata // data
    ) external view override {
        _checkNftOwnership(follower, profileId);
    }

    function followModuleTransferHook(
        uint256 profileId,
        address from,
        address to,
        uint256 followNFTTokenId
    ) external view override {
        _checkNftOwnership(to, profileId);
    }

    function getNfts(uint256 _profileId) external view returns (address[] memory) {
        uint256 nftCount = nftsByProfile[_profileId].length;
        address[] memory nfts = new address[](nftCount);

        for (uint256 i = 0; i < nftCount; ) {
            nfts[i] = nftsByProfile[_profileId][i];
            unchecked {
                i++;
            }
        }

        return nfts;
    }

    function setNfts(uint256 profileId, address[] calldata nftAddresses) external {
        require(IERC721(HUB).ownerOf(profileId) == msg.sender, 'ONLY_PROFILE_OWNER');
        nftsByProfile[profileId] = nftAddresses;
    }

    function _checkNftOwnership(address _user, uint256 _profileId) private view {
        if (nftsByProfile[_profileId].length != 0) {
            for (uint256 i = 0; i < nftsByProfile[_profileId].length; ) {
                if (IERC721(nftsByProfile[_profileId][i]).balanceOf(_user) > 0) {
                    revert Errors.InsufficientBalance();
                }
                unchecked {
                    i++;
                }
            }
        }
    }
}
