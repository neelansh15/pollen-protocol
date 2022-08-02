// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from './FollowValidatorFollowModuleBase.sol';

import {IFollowModule} from '../../../interfaces/IFollowModule.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title ERC721GateFollowModule
 * @author Neelansh Mathur
 *
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
    ) external override view {
        _checkNftOwnership(to, profileId);
    }

    function _checkNftOwnership(address _user, uint256 _profileId) private view {
        require(IERC721(nftByProfile[_profileId]).balanceOf(_user) > 0, "NO_NFT_BALANCE");
    }
}
