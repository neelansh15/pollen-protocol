// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {ModuleBase} from '../../ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from '../FollowValidatorFollowModuleBase.sol';

import {IFollowModule} from '../../../../interfaces/IFollowModule.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title ERC721GateFollowModule
 * @author Neelansh Mathur
 * @dev Allows holders of a certain NFT to follow
 **/
contract ERC721GateFollowModule is IFollowModule, FollowValidatorFollowModuleBase {
    mapping(uint256 => address) public nftByProfile;

    string public description = 'Follow allowed only if you hold a certain NFT';

    constructor(address hub) ModuleBase(hub) {}

    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        override
        onlyHub
        returns (bytes memory)
    {
        nftByProfile[profileId] = abi.decode(data, (address));
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

    function setNft(uint256 profileId, address nftAddress) external {
        require(IERC721(HUB).ownerOf(profileId) == msg.sender, 'ONLY_PROFILE_OWNER');
        nftByProfile[profileId] = nftAddress;
    }

    function _checkNftOwnership(address _user, uint256 _profileId) private view {
        if (nftByProfile[_profileId] != address(0)) {
            require(
                IERC721(nftByProfile[_profileId]).balanceOf(_user) > 0,
                'INSUFFICIENT_NFT_BALANCE'
            );
        }
    }
}
