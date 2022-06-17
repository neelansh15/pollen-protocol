pragma solidity 0.8.14;

import '../libraries/Constants.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {MetaTxHelpers} from '../libraries/MetaTxHelpers.sol';
import {Helpers} from '../libraries/Helpers.sol';
import {InteractionHelpers} from '../libraries/InteractionHelpers.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';

import {ICollectModule} from '../interfaces/ICollectModule.sol';
import {IReferenceModule} from '../interfaces/IReferenceModule.sol';
import {IFollowModule} from '../interfaces/IFollowModule.sol';
import {LensHubDelegationStorage} from './storage/LensHubDelegationStorage.sol';

contract LensHubDelegation is LensHubDelegationStorage {
    address internal immutable COLLECT_NFT_IMPL;

    // ERC721 Events
    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev The constructor sets the immutable collect NFT implementations.
     *
     * @param collectNFTImpl The collect NFT implementation address.
     */
    constructor(address followNFTImpl, address collectNFTImpl) {
        if (collectNFTImpl == address(0)) revert Errors.InitParamsInvalid();
        COLLECT_NFT_IMPL = collectNFTImpl;
    }

    // ERC721 Functionality

    function permit(
        address spender,
        uint256 tokenId,
        DataTypes.EIP712Signature calldata sig
    ) external {
        address owner = _ownerOf(tokenId);
        MetaTxHelpers.basePermit(owner, spender, tokenId, sig);
        _approveNoEvent(spender, tokenId);
        // We don't emit the event in the _approve() function to avoid accessing the owner in
        // storage twice.
        emit Approval(owner, spender, tokenId);
    }

    /**
     * @notice Approves an address to operate on an owner's tokens via signature.
     *
     * @param owner The owner to approve the operator for, this is the signer.
     * @param operator The operator to approve for the owner.
     * @param approved Whether or not the operator should be approved.
     * @param sig the EIP712Signature struct containing the token owner's signature.
     */
    function permitForAll(
        address owner,
        address operator,
        bool approved,
        DataTypes.EIP712Signature calldata sig
    ) external {
        MetaTxHelpers.basePermitForAll(owner, operator, approved, sig);
        _setOperatorApproval(owner, operator, approved);
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @notice Sets the governance address.
     *
     * @param newGovernance The new governance address to set.
     */
    function setGovernance(address newGovernance) external {
        address prevGovernance = _governance;
        _governance = newGovernance;
        emit Events.GovernanceSet(msg.sender, prevGovernance, newGovernance, block.timestamp);
    }

    /**
     * @notice Sets the emergency admin address.
     *
     * @param newEmergencyAdmin The new governance address to set.
     */
    function setEmergencyAdmin(address newEmergencyAdmin) external {
        address prevEmergencyAdmin = _emergencyAdmin;
        _emergencyAdmin = newEmergencyAdmin;
        emit Events.EmergencyAdminSet(
            msg.sender,
            prevEmergencyAdmin,
            newEmergencyAdmin,
            block.timestamp
        );
    }

    /**
     * @notice Sets the protocol state.
     *
     * @param newState The new protocol state to set.
     *
     * Note: This does NOT validate the caller, and is only to be used for initialization.
     */
    function setStateSimple(DataTypes.ProtocolState newState) external {
        DataTypes.ProtocolState prevState = _state;
        _state = newState;
        emit Events.StateSet(msg.sender, prevState, newState, block.timestamp);
    }

    /**
     * @notice Sets the protocol state and validates the caller. The emergency admin can only
     * pause further (Unpaused => PublishingPaused => Paused). Whereas governance can set any
     * state.
     *
     * @param newState The new protocol state to set.
     */
    function setStateFull(DataTypes.ProtocolState newState) external {
        DataTypes.ProtocolState prevState = _state;
        _state = newState;
        if (msg.sender == _emergencyAdmin) {
            if (newState == DataTypes.ProtocolState.Unpaused)
                revert Errors.EmergencyAdminCannotUnpause();
            if (prevState == DataTypes.ProtocolState.Paused) revert Errors.Paused();
        } else if (msg.sender != _governance) {
            revert Errors.NotGovernanceOrEmergencyAdmin();
        }
        emit Events.StateSet(msg.sender, prevState, newState, block.timestamp);
    }

    /**
     * @notice Executes the logic to create a profile with the given parameters to the given address.
     *
     * @param vars The CreateProfileData struct containing the following parameters:
     *      to: The address receiving the profile.
     *      handle: The handle to set for the profile, must be unique and non-empty.
     *      imageURI: The URI to set for the profile image.
     *      followModule: The follow module to use, can be the zero address.
     *      followModuleInitData: The follow module initialization data, if any
     *      followNFTURI: The URI to set for the follow NFT.
     * @param profileId The profile ID to associate with this profile NFT (token ID).
     */
    function createProfile(DataTypes.CreateProfileData calldata vars, uint256 profileId) external {
        _validateHandle(vars.handle);

        if (bytes(vars.imageURI).length > MAX_PROFILE_IMAGE_URI_LENGTH)
            revert Errors.ProfileImageURILengthInvalid();

        bytes32 handleHash = keccak256(bytes(vars.handle));

        if (_profileIdByHandleHash[handleHash] != 0) revert Errors.HandleTaken();

        _profileIdByHandleHash[handleHash] = profileId;
        _profileById[profileId].handle = vars.handle;
        _profileById[profileId].imageURI = vars.imageURI;
        _profileById[profileId].followNFTURI = vars.followNFTURI;

        bytes memory followModuleReturnData;
        if (vars.followModule != address(0)) {
            _profileById[profileId].followModule = vars.followModule;
            followModuleReturnData = _initFollowModule(
                profileId,
                vars.followModule,
                vars.followModuleInitData,
                _followModuleWhitelisted
            );
        }

        _emitProfileCreated(profileId, vars, followModuleReturnData);
    }

    function setDefaultProfile(address wallet, uint256 profileId) external {
        _setDefaultProfile(wallet, profileId);
    }

    /**
     * @notice Sets the default profile via signature for a given owner.
     *
     * @param vars the SetDefaultProfileWithSigData struct containing the relevant parameters.
     */
    function setDefaultProfileWithSig(DataTypes.SetDefaultProfileWithSigData calldata vars)
        external
    {
        MetaTxHelpers.baseSetDefaultProfileWithSig(vars);
        _setDefaultProfile(vars.wallet, vars.profileId);
    }

    /**
     * @notice Sets the follow module for a given profile.
     *
     * @param profileId The profile ID to set the follow module for.
     * @param followModule The follow module to set for the given profile, if any.
     * @param followModuleInitData The data to pass to the follow module for profile initialization.
     */
    function setFollowModule(
        uint256 profileId,
        address followModule,
        bytes calldata followModuleInitData
    ) external {
        _validateCallerIsProfileOwner(profileId);
        _setFollowModule(profileId, followModule, followModuleInitData);
    }

    /**
     * @notice sets the follow module via signature for a given profile.
     *
     * @param vars the SetFollowModuleWithSigData struct containing the relevant parameters.
     */
    function setFollowModuleWithSig(DataTypes.SetFollowModuleWithSigData calldata vars) external {
        MetaTxHelpers.baseSetFollowModuleWithSig(vars);
        _setFollowModule(vars.profileId, vars.followModule, vars.followModuleInitData);
    }

    function setDispatcher(uint256 profileId, address dispatcher) external {
        _validateCallerIsProfileOwner(profileId);
        _setDispatcher(profileId, dispatcher);
    }

    /**
     * @notice Sets the dispatcher for a given profile via signature.
     *
     * @param vars the setDispatcherWithSigData struct containing the relevant parameters.
     */
    function setDispatcherWithSig(DataTypes.SetDispatcherWithSigData calldata vars) external {
        MetaTxHelpers.baseSetDispatcherWithSig(vars);
        _setDispatcher(vars.profileId, vars.dispatcher);
    }

    function setProfileImageURI(uint256 profileId, string calldata imageURI) external {
        _validateCallerIsProfileOwnerOrDispatcher(profileId);
        _setProfileImageURI(profileId, imageURI);
    }

    /**
     * @notice Sets the profile image URI via signature for a given profile.
     *
     * @param vars the SetProfileImageURIWithSigData struct containing the relevant parameters.
     */
    function setProfileImageURIWithSig(DataTypes.SetProfileImageURIWithSigData calldata vars)
        external
    {
        MetaTxHelpers.baseSetProfileImageURIWithSig(vars);
        _setProfileImageURI(vars.profileId, vars.imageURI);
    }

    function setFollowNFTURI(uint256 profileId, string calldata followNFTURI) external {
        _validateCallerIsProfileOwnerOrDispatcher(profileId);
        _setFollowNFTURI(profileId, followNFTURI);
    }

    /**
     * @notice Sets the follow NFT URI via signature for a given profile.
     *
     * @param vars the SetFollowNFTURIWithSigData struct containing the relevant parameters.
     */
    function setFollowNFTURIWithSig(DataTypes.SetFollowNFTURIWithSigData calldata vars) external {
        MetaTxHelpers.baseSetFollowNFTURIWithSig(vars);
        _setFollowNFTURI(vars.profileId, vars.followNFTURI);
    }

    function post(DataTypes.PostData calldata vars) external returns (uint256) {
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
            _createPost(
                vars.profileId,
                pubId,
                vars.contentURI,
                vars.collectModule,
                vars.collectModuleInitData,
                vars.referenceModule,
                vars.referenceModuleInitData
            );
            return pubId;
        }
    }

    /**
     * @notice Validates parameters and increments the nonce for a given owner using the
     * `postWithSig()` function.
     *
     * @param vars the PostWithSigData struct containing the relevant parameters.
     */
    function postWithSig(DataTypes.PostWithSigData calldata vars) external returns (uint256) {
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            MetaTxHelpers.basePostWithSig(vars);
            _createPost(
                vars.profileId,
                pubId,
                vars.contentURI,
                vars.collectModule,
                vars.collectModuleInitData,
                vars.referenceModule,
                vars.referenceModuleInitData
            );
            return pubId;
        }
    }

    function comment(DataTypes.CommentData calldata vars) external returns (uint256) {
        _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            _createComment(vars, pubId);
            return pubId;
        }
    }

    /**
     * @notice Validates parameters and increments the nonce for a given owner using the
     * `commentWithSig()` function.
     *
     * @param vars the CommentWithSig struct containing the relevant parameters.
     */
    function commentWithSig(DataTypes.CommentWithSigData calldata vars) external returns (uint256) {
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            MetaTxHelpers.baseCommentWithSig(vars);
            _createCommentWithSigStruct(vars, pubId);
            return pubId;
        }
    }

    function mirror(DataTypes.MirrorData calldata vars) external returns (uint256) {
        // uint256 pubId = _preIncrementPubCount(vars.profileId);
        _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            _createMirror(vars, pubId);
            return pubId;
        }
    }

    /**
     * @notice Validates parameters and increments the nonce for a given owner using the
     * `mirrorWithSig()` function.
     *
     * @param vars the MirrorWithSigData struct containing the relevant parameters.
     */
    function mirrorWithSig(DataTypes.MirrorWithSigData calldata vars) external returns (uint256) {
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            MetaTxHelpers.baseMirrorWithSig(vars);
            _createMirrorWithSigStruct(vars, pubId);
            return pubId;
        }
    }

    /**
     * @notice Follows the given profiles, executing the necessary logic and module calls before minting the follow
     * NFT(s) to the follower.
     *
     * @param profileIds The array of profile token IDs to follow.
     * @param followModuleDatas The array of follow module data parameters to pass to each profile's follow module.
     *
     * @return uint256[] An array of integers representing the minted follow NFTs token IDs.
     */
    function follow(uint256[] calldata profileIds, bytes[] calldata followModuleDatas)
        external
        returns (uint256[] memory)
    {
        return
            InteractionHelpers.follow(
                msg.sender,
                profileIds,
                followModuleDatas,
                _profileById,
                _profileIdByHandleHash
            );
    }

    /**
     * @notice Validates parameters and increments the nonce for a given owner using the
     * `followWithSig()` function.
     *
     * @param vars the FollowWithSigData struct containing the relevant parameters.
     */
    function followWithSig(DataTypes.FollowWithSigData calldata vars)
        external
        returns (uint256[] memory)
    {
        MetaTxHelpers.baseFollowWithSig(vars);
        return
            InteractionHelpers.follow(
                vars.follower,
                vars.profileIds,
                vars.datas,
                _profileById,
                _profileIdByHandleHash
            );
    }

    /**
     * @notice Collects the given publication, executing the necessary logic and module call before minting the
     * collect NFT to the collector.
     *
     * @param profileId The token ID of the publication being collected's parent profile.
     * @param pubId The publication ID of the publication being collected.
     * @param collectModuleData The data to pass to the publication's collect module.
     *
     * @return uint256 An integer representing the minted token ID.
     */
    function collect(
        uint256 profileId,
        uint256 pubId,
        bytes calldata collectModuleData
    ) external returns (uint256) {
        return
            InteractionHelpers.collect(
                msg.sender,
                profileId,
                pubId,
                collectModuleData,
                COLLECT_NFT_IMPL,
                _pubByIdByProfile,
                _profileById
            );
    }

    /**
     * @notice Validates parameters and increments the nonce for a given owner using the
     * `collectWithSig()` function.
     *
     * @param vars the CollectWithSigData struct containing the relevant parameters.
     */
    function collectWithSig(DataTypes.CollectWithSigData calldata vars) external returns (uint256) {
        MetaTxHelpers.baseCollectWithSig(vars);
        return
            InteractionHelpers.collect(
                vars.collector,
                vars.profileId,
                vars.pubId,
                vars.data,
                COLLECT_NFT_IMPL,
                _pubByIdByProfile,
                _profileById
            );
    }

    /**
     * @notice Validates parameters and increments the nonce for a given owner using the
     * `burnWithSig()` function.
     *
     * @param tokenId The token ID to burn.
     * @param sig the EIP712Signature struct containing the token owner's signature.
     */
    function preProcessBurnWithSig(uint256 tokenId, DataTypes.EIP712Signature calldata sig)
        external
    {
        MetaTxHelpers.baseBurnWithSig(tokenId, sig);
    }

    /**
     * @notice Returns the domain separator.
     *
     * @return bytes32 The domain separator.
     */
    function getDomainSeparator() external view returns (bytes32) {
        return MetaTxHelpers.getDomainSeparator();
    }

    // ERC721 Functions

    /**
     * @dev Approve `to` to operate on `tokenId`
     */
    function _approveNoEvent(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
    }

    /**
     * @dev Refactored from the original OZ ERC721 implementation: approve or revoke approval from
     * `operator` to operate on all tokens owned by `owner`.
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setOperatorApproval(
        address owner,
        address operator,
        bool approved
    ) private {
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function _ownerOf(uint256 tokenId) private view returns (address) {
        address owner = _tokenData[tokenId].owner;
        if (owner == address(0)) revert Errors.ERC721Time_OwnerQueryForNonexistantToken();
        return owner;
    }

    function _setDefaultProfile(address wallet, uint256 profileId) private {
        if (profileId > 0 && wallet != _ownerOf(profileId)) revert Errors.NotProfileOwner();
        _defaultProfileByAddress[wallet] = profileId;
        emit Events.DefaultProfileSet(wallet, profileId, block.timestamp);
    }

    function _setProfileImageURI(uint256 profileId, string calldata imageURI) private {
        if (bytes(imageURI).length > MAX_PROFILE_IMAGE_URI_LENGTH)
            revert Errors.ProfileImageURILengthInvalid();
        _profileById[profileId].imageURI = imageURI;
        emit Events.ProfileImageURISet(profileId, imageURI, block.timestamp);
    }

    function _setFollowNFTURI(uint256 profileId, string calldata followNFTURI) private {
        _profileById[profileId].followNFTURI = followNFTURI;
        emit Events.FollowNFTURISet(profileId, followNFTURI, block.timestamp);
    }

    /**
     * @notice Sets the follow module for a given profile.
     *
     * @param profileId The profile ID to set the follow module for.
     * @param followModule The follow module to set for the given profile, if any.
     * @param followModuleInitData The data to pass to the follow module for profile initialization.
     */
    function _setFollowModule(
        uint256 profileId,
        address followModule,
        bytes calldata followModuleInitData
    ) private {
        if (followModule != _profileById[profileId].followModule) {
            _profileById[profileId].followModule = followModule;
        }

        bytes memory followModuleReturnData;
        if (followModule != address(0))
            followModuleReturnData = _initFollowModule(
                profileId,
                followModule,
                followModuleInitData,
                _followModuleWhitelisted
            );
        emit Events.FollowModuleSet(
            profileId,
            followModule,
            followModuleReturnData,
            block.timestamp
        );
    }

    function _setDispatcher(uint256 profileId, address dispatcher) private {
        _dispatcherByProfile[profileId] = dispatcher;
        emit Events.DispatcherSet(profileId, dispatcher, block.timestamp);
    }

    /**
     * @notice Creates a post publication mapped to the given profile.
     *
     * @dev To avoid a stack too deep error, reference parameters are passed in memory rather than calldata.
     *
     * @param profileId The profile ID to associate this publication to.
     * @param pubId The publication ID to associate with this publication.
     * @param contentURI The URI to set for this publication.
     * @param collectModule The collect module to set for this publication.
     * @param collectModuleInitData The data to pass to the collect module for publication initialization.
     * @param referenceModule The reference module to set for this publication, if any.
     * @param referenceModuleInitData The data to pass to the reference module for publication initialization.
     */
    function _createPost(
        uint256 profileId,
        uint256 pubId,
        string memory contentURI,
        address collectModule,
        bytes memory collectModuleInitData,
        address referenceModule,
        bytes memory referenceModuleInitData
    ) private {
        _pubByIdByProfile[profileId][pubId].contentURI = contentURI;

        // Collect module initialization
        bytes memory collectModuleReturnData = _initPubCollectModule(
            profileId,
            pubId,
            collectModule,
            collectModuleInitData,
            _pubByIdByProfile,
            _collectModuleWhitelisted
        );

        // Reference module initialization
        bytes memory referenceModuleReturnData = _initPubReferenceModule(
            profileId,
            pubId,
            referenceModule,
            referenceModuleInitData,
            _pubByIdByProfile,
            _referenceModuleWhitelisted
        );

        emit Events.PostCreated(
            profileId,
            pubId,
            contentURI,
            collectModule,
            collectModuleReturnData,
            referenceModule,
            referenceModuleReturnData,
            block.timestamp
        );
    }

    /**
     * @notice Creates a comment publication mapped to the given profile.
     *
     * @dev This function is unique in that it requires many variables, so, unlike the other publishing functions,
     * we need to pass the full CommentData struct in memory to avoid a stack too deep error.
     *
     * @param vars The CommentData struct to use to create the comment.
     * @param pubId The publication ID to associate with this publication.
     */
    function _createComment(DataTypes.CommentData calldata vars, uint256 pubId) private {
        // Validate existence of the pointed publication
        uint256 pubCount = _profileById[vars.profileIdPointed].pubCount;
        if (pubCount < vars.pubIdPointed || vars.pubIdPointed == 0)
            revert Errors.PublicationDoesNotExist();

        // Ensure the pointed publication is not the comment being created
        if (vars.profileId == vars.profileIdPointed && vars.pubIdPointed == pubId)
            revert Errors.CannotCommentOnSelf();

        _pubByIdByProfile[vars.profileId][pubId].contentURI = vars.contentURI;
        _pubByIdByProfile[vars.profileId][pubId].profileIdPointed = vars.profileIdPointed;
        _pubByIdByProfile[vars.profileId][pubId].pubIdPointed = vars.pubIdPointed;

        // Collect Module Initialization
        bytes memory collectModuleReturnData = _initPubCollectModule(
            vars.profileId,
            pubId,
            vars.collectModule,
            vars.collectModuleInitData,
            _pubByIdByProfile,
            _collectModuleWhitelisted
        );

        // Reference module initialization
        bytes memory referenceModuleReturnData = _initPubReferenceModule(
            vars.profileId,
            pubId,
            vars.referenceModule,
            vars.referenceModuleInitData,
            _pubByIdByProfile,
            _referenceModuleWhitelisted
        );

        // Reference module validation
        address refModule = _pubByIdByProfile[vars.profileIdPointed][vars.pubIdPointed]
            .referenceModule;
        if (refModule != address(0)) {
            IReferenceModule(refModule).processComment(
                vars.profileId,
                vars.profileIdPointed,
                vars.pubIdPointed,
                vars.referenceModuleData
            );
        }

        // Prevents a stack too deep error
        _emitCommentCreated(vars, pubId, collectModuleReturnData, referenceModuleReturnData);
    }

    function _emitCommentCreated(
        DataTypes.CommentData calldata vars,
        uint256 pubId,
        bytes memory collectModuleReturnData,
        bytes memory referenceModuleReturnData
    ) private {
        emit Events.CommentCreated(
            vars.profileId,
            pubId,
            vars.contentURI,
            vars.profileIdPointed,
            vars.pubIdPointed,
            vars.referenceModuleData,
            vars.collectModule,
            collectModuleReturnData,
            vars.referenceModule,
            referenceModuleReturnData,
            block.timestamp
        );
    }

    /**
     * @notice Creates a comment publication mapped to the given profile.
     *
     * @dev This function is unique in that it requires many variables, so, unlike the other publishing functions,
     * we need to pass the full CommentData struct in memory to avoid a stack too deep error.
     *
     * @param vars The CommentWithSigData struct to use to create the comment.
     * @param pubId The publication ID to associate with this publication.
     */
    function _createCommentWithSigStruct(DataTypes.CommentWithSigData calldata vars, uint256 pubId)
        private
    {
        // Validate existence of the pointed publication
        uint256 pubCount = _profileById[vars.profileIdPointed].pubCount;
        if (pubCount < vars.pubIdPointed || vars.pubIdPointed == 0)
            revert Errors.PublicationDoesNotExist();

        // Ensure the pointed publication is not the comment being created
        if (vars.profileId == vars.profileIdPointed && vars.pubIdPointed == pubId)
            revert Errors.CannotCommentOnSelf();

        _pubByIdByProfile[vars.profileId][pubId].contentURI = vars.contentURI;
        _pubByIdByProfile[vars.profileId][pubId].profileIdPointed = vars.profileIdPointed;
        _pubByIdByProfile[vars.profileId][pubId].pubIdPointed = vars.pubIdPointed;

        // Collect Module Initialization
        bytes memory collectModuleReturnData = _initPubCollectModule(
            vars.profileId,
            pubId,
            vars.collectModule,
            vars.collectModuleInitData,
            _pubByIdByProfile,
            _collectModuleWhitelisted
        );

        // Reference module initialization
        bytes memory referenceModuleReturnData = _initPubReferenceModule(
            vars.profileId,
            pubId,
            vars.referenceModule,
            vars.referenceModuleInitData,
            _pubByIdByProfile,
            _referenceModuleWhitelisted
        );

        // Reference module validation
        address refModule = _pubByIdByProfile[vars.profileIdPointed][vars.pubIdPointed]
            .referenceModule;
        if (refModule != address(0)) {
            IReferenceModule(refModule).processComment(
                vars.profileId,
                vars.profileIdPointed,
                vars.pubIdPointed,
                vars.referenceModuleData
            );
        }

        // Prevents a stack too deep error
        _emitCommentCreatedWithSigStruct(
            vars,
            pubId,
            collectModuleReturnData,
            referenceModuleReturnData
        );
    }

    function _emitCommentCreatedWithSigStruct(
        DataTypes.CommentWithSigData calldata vars,
        uint256 pubId,
        bytes memory collectModuleReturnData,
        bytes memory referenceModuleReturnData
    ) private {
        emit Events.CommentCreated(
            vars.profileId,
            pubId,
            vars.contentURI,
            vars.profileIdPointed,
            vars.pubIdPointed,
            vars.referenceModuleData,
            vars.collectModule,
            collectModuleReturnData,
            vars.referenceModule,
            referenceModuleReturnData,
            block.timestamp
        );
    }

    /**
     * @notice Creates a mirror publication mapped to the given profile.
     *
     * @param vars The MirrorData struct to use to create the mirror.
     * @param pubId The publication ID to associate with this publication.
     */
    function _createMirror(DataTypes.MirrorData memory vars, uint256 pubId) private {
        (uint256 rootProfileIdPointed, uint256 rootPubIdPointed) = Helpers.getPointedIfMirror(
            vars.profileIdPointed,
            vars.pubIdPointed,
            _pubByIdByProfile
        );

        _pubByIdByProfile[vars.profileId][pubId].profileIdPointed = rootProfileIdPointed;
        _pubByIdByProfile[vars.profileId][pubId].pubIdPointed = rootPubIdPointed;

        // Reference module initialization
        bytes memory referenceModuleReturnData = _initPubReferenceModule(
            vars.profileId,
            pubId,
            vars.referenceModule,
            vars.referenceModuleInitData,
            _pubByIdByProfile,
            _referenceModuleWhitelisted
        );

        // Reference module validation
        address refModule = _pubByIdByProfile[rootProfileIdPointed][rootPubIdPointed]
            .referenceModule;
        if (refModule != address(0)) {
            IReferenceModule(refModule).processMirror(
                vars.profileId,
                rootProfileIdPointed,
                rootPubIdPointed,
                vars.referenceModuleData
            );
        }

        emit Events.MirrorCreated(
            vars.profileId,
            pubId,
            rootProfileIdPointed,
            rootPubIdPointed,
            vars.referenceModuleData,
            vars.referenceModule,
            referenceModuleReturnData,
            block.timestamp
        );
    }

    /**
     * @notice Creates a mirror publication mapped to the given profile.
     *
     * @param vars The MirrorData struct to use to create the mirror.
     * @param pubId The publication ID to associate with this publication.
     */
    function _createMirrorWithSigStruct(DataTypes.MirrorWithSigData memory vars, uint256 pubId)
        private
    {
        (uint256 rootProfileIdPointed, uint256 rootPubIdPointed) = Helpers.getPointedIfMirror(
            vars.profileIdPointed,
            vars.pubIdPointed,
            _pubByIdByProfile
        );

        _pubByIdByProfile[vars.profileId][pubId].profileIdPointed = rootProfileIdPointed;
        _pubByIdByProfile[vars.profileId][pubId].pubIdPointed = rootPubIdPointed;

        // Reference module initialization
        bytes memory referenceModuleReturnData = _initPubReferenceModule(
            vars.profileId,
            pubId,
            vars.referenceModule,
            vars.referenceModuleInitData,
            _pubByIdByProfile,
            _referenceModuleWhitelisted
        );

        // Reference module validation
        address refModule = _pubByIdByProfile[rootProfileIdPointed][rootPubIdPointed]
            .referenceModule;
        if (refModule != address(0)) {
            IReferenceModule(refModule).processMirror(
                vars.profileId,
                rootProfileIdPointed,
                rootPubIdPointed,
                vars.referenceModuleData
            );
        }

        emit Events.MirrorCreated(
            vars.profileId,
            pubId,
            rootProfileIdPointed,
            rootPubIdPointed,
            vars.referenceModuleData,
            vars.referenceModule,
            referenceModuleReturnData,
            block.timestamp
        );
    }

    function _validateCallerIsProfileOwner(uint256 profileId) internal view {
        if (msg.sender != _ownerOf(profileId)) revert Errors.NotProfileOwner();
    }

    function _validateCallerIsProfileOwnerOrDispatcher(uint256 profileId) private view {
        if (msg.sender == _ownerOf(profileId) || msg.sender == _dispatcherByProfile[profileId]) {
            return;
        }
        revert Errors.NotProfileOwnerOrDispatcher();
    }

    function _initPubCollectModule(
        uint256 profileId,
        uint256 pubId,
        address collectModule,
        bytes memory collectModuleInitData,
        mapping(uint256 => mapping(uint256 => DataTypes.PublicationStruct))
            storage _pubByIdByProfile,
        mapping(address => bool) storage _collectModuleWhitelisted
    ) private returns (bytes memory) {
        if (!_collectModuleWhitelisted[collectModule]) revert Errors.CollectModuleNotWhitelisted();
        _pubByIdByProfile[profileId][pubId].collectModule = collectModule;
        return
            ICollectModule(collectModule).initializePublicationCollectModule(
                profileId,
                pubId,
                collectModuleInitData
            );
    }

    function _initPubReferenceModule(
        uint256 profileId,
        uint256 pubId,
        address referenceModule,
        bytes memory referenceModuleInitData,
        mapping(uint256 => mapping(uint256 => DataTypes.PublicationStruct))
            storage _pubByIdByProfile,
        mapping(address => bool) storage _referenceModuleWhitelisted
    ) private returns (bytes memory) {
        if (referenceModule == address(0)) return new bytes(0);
        if (!_referenceModuleWhitelisted[referenceModule])
            revert Errors.ReferenceModuleNotWhitelisted();
        _pubByIdByProfile[profileId][pubId].referenceModule = referenceModule;
        return
            IReferenceModule(referenceModule).initializeReferenceModule(
                profileId,
                pubId,
                referenceModuleInitData
            );
    }

    function _initFollowModule(
        uint256 profileId,
        address followModule,
        bytes memory followModuleInitData,
        mapping(address => bool) storage _followModuleWhitelisted
    ) private returns (bytes memory) {
        if (!_followModuleWhitelisted[followModule]) revert Errors.FollowModuleNotWhitelisted();
        return IFollowModule(followModule).initializeFollowModule(profileId, followModuleInitData);
    }

    function _emitProfileCreated(
        uint256 profileId,
        DataTypes.CreateProfileData calldata vars,
        bytes memory followModuleReturnData
    ) private {
        emit Events.ProfileCreated(
            profileId,
            msg.sender, // Creator is always the msg sender
            vars.to,
            vars.handle,
            vars.imageURI,
            vars.followModule,
            followModuleReturnData,
            vars.followNFTURI,
            block.timestamp
        );
    }

    function _validateHandle(string calldata handle) private pure {
        bytes memory byteHandle = bytes(handle);
        if (byteHandle.length == 0 || byteHandle.length > MAX_HANDLE_LENGTH)
            revert Errors.HandleLengthInvalid();

        uint256 byteHandleLength = byteHandle.length;
        for (uint256 i = 0; i < byteHandleLength; ) {
            if (
                (byteHandle[i] < '0' ||
                    byteHandle[i] > 'z' ||
                    (byteHandle[i] > '9' && byteHandle[i] < 'a')) &&
                byteHandle[i] != '.' &&
                byteHandle[i] != '-' &&
                byteHandle[i] != '_'
            ) revert Errors.HandleContainsInvalidCharacters();
            unchecked {
                ++i;
            }
        }
    }
}
