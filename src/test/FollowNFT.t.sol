// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTestPlus} from 'solmate/test/utils/DSTestPlus.sol';

import {ModuleGlobals} from 'lens/core/modules/Moduleglobals.sol';
import {LensHub} from 'lens/core/LensHub.sol';
import {FollowNFT} from 'lens/core/FollowNFT.sol';
import {CollectNFT} from 'lens/core/CollectNFT.sol';
import {TransparentUpgradeableProxy} from 'lens/upgradeability/TransparentUpgradeableProxy.sol';
import {EmptyCollectModule} from 'lens/core/modules/collect/EmptyCollectModule.sol';
import {FollowerOnlyReferenceModule} from 'lens/core/modules/reference/FollowerOnlyReferenceModule.sol';
import {MockFollowModule} from 'lens/mocks/MockFollowModule.sol';
import {DataTypes} from 'lens/libraries/DataTypes.sol';

contract FollowNFTTest is DSTestPlus {
    string constant MOCK_PROFILE_URI =
        'https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu';
    string constant MOCK_FOLLOW_NFT_URI =
        'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan';

    TransparentUpgradeableProxy internal proxy;
    LensHub internal HUB;
    FollowNFT internal NFT;

    uint256 constant P_ID = 1;
    address constant USER = address(0xdead);

    // TODO: Fetch address properly, right now just using the hardcoded address
    address constant PROXY_ADDRESS = address(0x12ed2382eB69F2322A352c6339d0774936bCE337);

    address internal ME;
    address internal ADMIN = address(0xf00ba);

    function setUp() public {
        ME = address(this);

        FollowNFT followImpl = new FollowNFT(PROXY_ADDRESS);
        CollectNFT collectImpl = new CollectNFT(PROXY_ADDRESS);
        LensHub hubLogic = new LensHub(address(followImpl), address(collectImpl));
        bytes memory data = abi.encodeWithSignature(
            'initialize(string,string,address)',
            'F',
            'F',
            ME
        );

        TransparentUpgradeableProxy tempProxy = new TransparentUpgradeableProxy(
            address(hubLogic),
            ADMIN,
            data
        );

        //emit log_named_address('Proxy', address(tempProxy));
        // TODO: To etch, need to also update state variables etc.
        //hevm.etch(PROXY_ADDRESS, address(tempProxy).code);
        proxy = tempProxy; // TransparentUpgradeableProxy(payable(PROXY_ADDRESS));

        EmptyCollectModule collectModule = new EmptyCollectModule(address(proxy));
        FollowerOnlyReferenceModule referenceModule = new FollowerOnlyReferenceModule(
            address(proxy)
        );
        MockFollowModule followModule = new MockFollowModule();

        HUB = LensHub(address(proxy));
        HUB.setState(DataTypes.ProtocolState.Unpaused);
        HUB.whitelistProfileCreator(ME, true);
        HUB.createProfile(
            DataTypes.CreateProfileData({
                to: USER,
                handle: 'abe',
                imageURI: MOCK_PROFILE_URI,
                followModule: address(0),
                followModuleData: '',
                followNFTURI: MOCK_FOLLOW_NFT_URI
            })
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = P_ID;
        bytes[] memory temp = new bytes[](1);

        HUB.follow(ids, temp);

        NFT = FollowNFT(HUB.getFollowNFT(P_ID));
    }

    function _checkValues(address user) public {
        emit log_named_address('User ', user);
        emit log_named_uint('Power', NFT.getPowerByBlockNumber(user, block.number));
    }

    function mutate(
        bool toRandom,
        bool transfer,
        address random,
        address from,
        address to,
        uint256 tokenId
    ) public {
        hevm.prank(from);

        if (transfer) {
            emit log_named_address('transfer', toRandom ? random : to);
            NFT.transferFrom(from, toRandom ? random : to, tokenId);
        } else {
            emit log_named_address('delegate', toRandom ? random : to);
            NFT.delegate(toRandom ? random : to);
        }
    }

    function testVotingPowerOverUnderFlow(
        uint8[5] calldata mintCounts,
        bool[5] calldata toRandoms,
        bool[5] calldata transfers,
        address[5] calldata randoms
    ) public {
        _checkValues(USER);

        uint256 followers = NFT.totalSupply();

        uint256[] memory ids = new uint256[](1);
        bytes[] memory temp = new bytes[](1);
        ids[0] = P_ID;

        for (uint256 i = 0; i < toRandoms.length; i++) {
            address tempUser = address(uint160(i + 1));
            uint256 mints = bound(mintCounts[i], 0, 10);

            hevm.startPrank(tempUser);
            for (uint256 j = 0; j < mints; j++) {
                HUB.follow(ids, temp);
                followers++;

                mutate(toRandoms[i], transfers[i], randoms[i], tempUser, USER, followers);

                _checkValues(USER);
                _checkValues(tempUser);
                if (toRandoms[i]) {
                    _checkValues(randoms[i]);
                }
            }
            hevm.stopPrank();
        }
    }
}
