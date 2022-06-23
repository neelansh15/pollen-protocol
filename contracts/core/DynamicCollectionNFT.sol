// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IDynamicCollectionNFT} from '../interfaces/IDynamicCollectionNFT.sol';
import {ILensHub} from '../interfaces/ILensHub.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';
import {LensNFTBase} from './base/LensNFTBase.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

/**
 * @title DynamicColleciontNFT
 * @author Lens Protocol
 *
 * @notice This is the NFT contract that is minted upon collecting a given publication. It is cloned upon
 * the first collect for a given publication, and the token URI points to the original publication's contentURI.
 */
contract DynamicColleciontNFT is LensNFTBase, IDynamicCollectionNFT {
    using Strings for uint256;

    address public immutable HUB;

    string internal __baseURI;
    uint256 internal _profileId;
    uint256 internal _pubId;
    uint256 internal _maxSupply;
    uint256 internal _tokenIdCounter;

    bool private _initialized;

    // randoness
    mapping(uint256 => uint256) indexer;
    mapping(uint256 => uint256) tokenIDMap;
    mapping(uint256 => uint256) takenImages;

    // We create the CollectNFT with the pre-computed HUB address before deploying the hub proxy in order
    // to initialize the hub proxy at construction.
    constructor(address hub) {
        if (hub == address(0)) revert Errors.InitParamsInvalid();
        HUB = hub;

        _initialized = true;
    }

    /// @inheritdoc IDynamicCollectionNFT
    function initialize(
        uint256 profileId,
        uint256 pubId,
        string memory baseURI__,
        uint256 maxSupply,
        string calldata name,
        string calldata symbol
    ) external override {
        if (_initialized) revert Errors.Initialized();
        _initialized = true;
        _profileId = profileId;
        _pubId = pubId;
        __baseURI = baseURI__;
        _maxSupply = maxSupply;
        super._initialize(name, symbol);
        emit Events.CollectNFTInitialized(profileId, pubId, block.timestamp);
    }

    function _baseURI() internal view override returns (string memory) {
        return __baseURI;
    }

    function _getNextImageID(uint256 index) private returns (uint256) {
        uint256 nextImageID = indexer[index];
        if (nextImageID == 0) {
            nextImageID = index;
        }

        if (indexer[_maxSupply - 1] == 0) {
            indexer[index] = _maxSupply - 1;
        } else {
            indexer[index] = indexer[_maxSupply - 1];
        }
        _maxSupply -= 1;

        return nextImageID;
    }

    function _enoughRandom() private view returns (uint256) {
        if (_maxSupply - _tokenIdCounter == 0) return 0;
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        msg.sender,
                        blockhash(block.number)
                    )
                )
            ) % (_maxSupply);
    }

    function _mintRandom(address to) private returns (uint256) {
        uint256 nextIndexerId = _enoughRandom();
        uint256 nextImageID = _getNextImageID(nextIndexerId);
        assert(takenImages[nextImageID] == 0);
        takenImages[nextImageID] = 1;
        tokenIDMap[_tokenIdCounter] = nextImageID;

        unchecked {
            uint256 tokenId = ++_tokenIdCounter;
            _mint(to, tokenId);
            return tokenId;
        }
    }

    /// @inheritdoc IDynamicCollectionNFT
    function mint(address to) external override returns (uint256) {
        if (msg.sender != HUB) revert Errors.NotHub();

        return _mintRandom(to);
    }

    /// @inheritdoc IDynamicCollectionNFT
    function getSourcePublicationPointer() external view override returns (uint256, uint256) {
        return (_profileId, _pubId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert Errors.TokenDoesNotExist();

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : '';
    }

    /**
     * @dev Upon transfers, we emit the transfer event in the hub.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        ILensHub(HUB).emitCollectNFTTransferEvent(_profileId, _pubId, tokenId, from, to);
    }
}
