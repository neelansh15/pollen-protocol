// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IReferenceModule} from '../../../interfaces/IReferenceModule.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {Errors} from '../../../libraries/Errors.sol';
import {FollowValidationModuleBase} from '../FollowValidationModuleBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {FeeModuleBase} from '../FeeModuleBase.sol';

struct ProfilePublicationData {
    uint256 mirrorLimit;
    uint256 currentMirrors;
    uint256 amount;
    address currency;
    address rewarder;
    bool followerOnly;
}

/**
 * @title LimitedRewardReferenceModule
 * @author Lens Protocol
 *
 * @notice A simple reference module that validates that comments or mirrors originate from a profile owned
 * by a follower and distributes a reward to a limited number of mirrors.
 */
contract LimitedRewardReferenceModule is
    FollowValidationModuleBase,
    IReferenceModule,
    FeeModuleBase
{
    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(uint256 => ProfilePublicationData))
        internal _dataByPublicationByProfile;

    constructor(address hub, address moduleGlobals) FeeModuleBase(moduleGlobals) ModuleBase(hub) {}

    /**
     * @dev There is nothing needed at initialization.
     */
    function initializeReferenceModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external override returns (bytes memory) {
        (
            uint256 amount,
            uint256 mirrorLimit,
            address currency,
            address rewarder,
            bool followerOnly
        ) = abi.decode(data, (uint256, uint256, address, address, bool));

        if (!_currencyWhitelisted(currency) || amount == 0) revert Errors.InitParamsInvalid();

        if (IERC20(currency).allowance(rewarder, address(this)) < amount)
            revert Errors.InsufficientAllowance();

        _dataByPublicationByProfile[profileId][pubId].amount = amount;
        _dataByPublicationByProfile[profileId][pubId].currency = currency;
        _dataByPublicationByProfile[profileId][pubId].followerOnly = followerOnly;
        _dataByPublicationByProfile[profileId][pubId].mirrorLimit = mirrorLimit;
        _dataByPublicationByProfile[profileId][pubId].rewarder = rewarder;

        return data;
    }

    /**
     * @notice Validates that the commenting profile's owner is a follower (if set).
     *
     * NOTE: We don't need to care what the pointed publication is in this context.
     */
    function processComment(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external view override {
        if (_dataByPublicationByProfile[profileIdPointed][pubIdPointed].followerOnly) {
            address commentCreator = IERC721(HUB).ownerOf(profileId);
            _checkFollowValidity(profileIdPointed, commentCreator);
        }
    }

    /**
     * @notice Validates that the commenting profile's owner is a follower (if set) and transfers reward tokens.
     *
     * NOTE: We don't need to care what the pointed publication is in this context.
     */
    function processMirror(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external override {
        address mirrorCreator = IERC721(HUB).ownerOf(profileId);
        if (_dataByPublicationByProfile[profileIdPointed][pubIdPointed].followerOnly) {
            _checkFollowValidity(profileIdPointed, mirrorCreator);
        }
        if (
            _dataByPublicationByProfile[profileIdPointed][pubIdPointed].currentMirrors >=
            _dataByPublicationByProfile[profileIdPointed][pubIdPointed].mirrorLimit
        ) {
            revert Errors.MintLimitExceeded();
        } else {
            ++_dataByPublicationByProfile[profileIdPointed][pubIdPointed].currentMirrors;

            // Equally distributed rewards: Reward = amount / mirrorLimit
            uint256 rewardAmount = _dataByPublicationByProfile[profileIdPointed][pubIdPointed]
                .amount / _dataByPublicationByProfile[profileIdPointed][pubIdPointed].mirrorLimit;

            IERC20(_dataByPublicationByProfile[profileIdPointed][pubIdPointed].currency)
                .safeTransferFrom(
                    _dataByPublicationByProfile[profileIdPointed][pubIdPointed].rewarder,
                    mirrorCreator,
                    rewardAmount
                );
        }
    }

    /**
     * @notice Returns the publication data for a given publication, or an empty struct if that publication was not
     * initialized with this module.
     *
     * @param profileId The token ID of the profile mapped to the publication to query.
     * @param pubId The publication ID of the publication to query.
     *
     * @return ProfilePublicationData The ProfilePublicationData struct mapped to that publication.
     */
    function getPublicationData(uint256 profileId, uint256 pubId)
        external
        view
        returns (ProfilePublicationData memory)
    {
        return _dataByPublicationByProfile[profileId][pubId];
    }
}
