// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {ModuleBase} from '../../ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from '../FollowValidatorFollowModuleBase.sol';

import {IFollowModule} from '../../../../interfaces/IFollowModule.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title MultipleOrERC721GateFollowModule
 * @author Neelansh Mathur
 * @dev Allows holders to follow if they hold at least one of the set NFTs
 **/
contract MultipleOrERC721GateFollowModule is IFollowModule, FollowValidatorFollowModuleBase {
    mapping(uint256 => address[]) public nftsByProfile;

    string public description = 'Follow allowed only if you hold at least one of the required NFTs';

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

    function setNfts(uint256 profileId, address[] calldata profileIds) external {
        require(IERC721(HUB).ownerOf(profileId) == msg.sender, 'ONLY_PROFILE_OWNER');
        nftsByProfile[profileId] = profileIds;
    }

    function _checkNftOwnership(address _user, uint256 _profileId) private view {
        if (nftsByProfile[_profileId].length != 0) {
            bool allow = false;
            for (uint256 i = 0; i <= nftsByProfile[_profileId].length; ) {
                if (IERC721(nftsByProfile[_profileId][i]).balanceOf(_user) > 0) {
                    allow = true;
                    break;
                }
                unchecked {
                    i++;
                }
            }
            require(allow, 'INSUFFICIENT_NFT_BALANCE');
        }
    }
}
