// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {Events} from './Events.sol';

library WhitelistingLogic {
    function _whitelistProfileCreator(
        address profileCreator,
        bool whitelist,
        mapping(address => bool) storage _profileCreatorWhitelisted
    ) external {
        _profileCreatorWhitelisted[profileCreator] = whitelist;
        emit Events.ProfileCreatorWhitelisted(profileCreator, whitelist, block.timestamp);
    }

    function _whitelistFollowModule(
        address followModule,
        bool whitelist,
        mapping(address => bool) storage _followModuleWhitelisted
    ) external {
        _followModuleWhitelisted[followModule] = whitelist;
        emit Events.FollowModuleWhitelisted(followModule, whitelist, block.timestamp);
    }

    function _whitelistReferenceModule(
        address referenceModule,
        bool whitelist,
        mapping(address => bool) storage _referenceModuleWhitelisted
    ) external {
        _referenceModuleWhitelisted[referenceModule] = whitelist;
        emit Events.ReferenceModuleWhitelisted(referenceModule, whitelist, block.timestamp);
    }

    function _whitelistCollectModule(
        address collectModule,
        bool whitelist,
        mapping(address => bool) storage _collectModuleWhitelisted
    ) external {
        _collectModuleWhitelisted[collectModule] = whitelist;
        emit Events.CollectModuleWhitelisted(collectModule, whitelist, block.timestamp);
    }
}
