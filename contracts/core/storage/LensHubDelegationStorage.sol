pragma solidity 0.8.14;

import {IERC721Time} from "../base/IERC721Time.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

abstract contract LensHubDelegationStorage {
    // Token name
    string internal _name;

    // Token symbol
    string internal _symbol;

    // Mapping from token ID to token Data (owner address and mint timestamp uint96), this
    // replaces the original mapping(uint256 => address) internal _owners;
    mapping(uint256 => IERC721Time.TokenData) internal _tokenData;

    // Mapping owner address to token count
    mapping(address => uint256) internal _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) internal _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) internal _operatorApprovals;
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) internal _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) internal _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] internal _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) internal _allTokensIndex;

    mapping(address => uint256) public sigNonces; // Slot 10

    uint256 internal lastInitializedRevision = 0;

    DataTypes.ProtocolState internal _state; // slot 12

    mapping(address => bool) internal _profileCreatorWhitelisted;       // Slot 13
    mapping(address => bool) internal _followModuleWhitelisted;         // Slot 14
    mapping(address => bool) internal _collectModuleWhitelisted;        // Slot 15
    mapping(address => bool) internal _referenceModuleWhitelisted;      // Slot 16

    mapping(uint256 => address) internal _dispatcherByProfile;          // slot 17
    mapping(bytes32 => uint256) internal _profileIdByHandleHash;        // slot 18
    mapping(uint256 => DataTypes.ProfileStruct) internal _profileById;  // slot 19
    mapping(uint256 => mapping(uint256 => DataTypes.PublicationStruct)) internal _pubByIdByProfile;  // slot 20

    mapping(address => uint256) internal _defaultProfileByAddress;      // slot 21

    uint256 internal _profileCounter;                                   // slot 22
    address internal _governance;                                       // slot 23
    address internal _emergencyAdmin;                                   // slot 24

}
