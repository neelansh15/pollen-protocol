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

    string public description = 'Follow allowed only if you hold all of the required NFTs';

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

    function _checkNftOwnership(address _user, uint256 _profileId) private view {
        bool allow = false;
        for (uint256 i = 1; i <= nftsByProfile[_profileId].length; i++) {
            if (IERC721(nftsByProfile[_profileId][i]).balanceOf(_user) > 0) {
                allow = true;
                break;
            }
        }
        require(allow, 'INSUFFICIENT_NFT_BALANCE');
    }
}
