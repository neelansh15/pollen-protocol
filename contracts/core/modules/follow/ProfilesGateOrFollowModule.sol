// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {ModuleBase} from '../../ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from '../FollowValidatorFollowModuleBase.sol';

import {ILensHub} from '../../../../interfaces/ILensHub.sol';
import {IFollowModule} from '../../../../interfaces/IFollowModule.sol';

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title ProfilesGateOrFollowModule
 * @author Neelansh Mathur
 * @dev Allow follow only if the user is already following at least one of the set Lens Profiles
 **/
contract ProfilesGateOrFollowModule is IFollowModule, FollowValidatorFollowModuleBase {
    mapping(uint256 => uint256[]) public IdsByProfile;

    string public description =
        'Follow allowed only if you follow at least one of the set profiles';

    constructor(address hub) ModuleBase(hub) {}

    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        override
        onlyHub
        returns (bytes memory)
    {
        IdsByProfile[profileId] = abi.decode(data, (uint256[]));
        return data;
    }

    function processFollow(
        address follower,
        uint256 profileId,
        bytes calldata // data
    ) external view override {
        _checkOwnership(follower, profileId);
    }

    function followModuleTransferHook(
        uint256 profileId,
        address from,
        address to,
        uint256 followNFTTokenId
    ) external view override {
        _checkOwnership(to, profileId);
    }

    function getAll(uint256 _profileId) external view returns (uint256[] memory) {
        uint256 nftCount = IdsByProfile[_profileId].length;
        uint256[] memory nfts = new uint256[](nftCount);

        for (uint256 i = 0; i < nftCount; ) {
            nfts[i] = IdsByProfile[_profileId][i];
            unchecked {
                i++;
            }
        }

        return nfts;
    }

    function setProfileIds(uint256 profileId, uint256[] calldata profileIds) external {
        require(IERC721(HUB).ownerOf(profileId) == msg.sender, 'ONLY_PROFILE_OWNER');
        IdsByProfile[profileId] = profileIds;
    }

    function _checkOwnership(address _user, uint256 _profileId) private view {
        if (IdsByProfile[_profileId].length != 0) {
            bool allow = false;
            for (uint256 i = 0; i < IdsByProfile[_profileId].length; ) {
                address followNFT = ILensHub(HUB).getFollowNFT(IdsByProfile[_profileId][i]);

                if (followNFT != address(0) && IERC721(followNFT).balanceOf(_user) > 0) {
                    allow = true;
                    break;
                }

                unchecked {
                    i++;
                }
            }
            require(allow, 'NO_FOLLOW');
        }
    }
}
