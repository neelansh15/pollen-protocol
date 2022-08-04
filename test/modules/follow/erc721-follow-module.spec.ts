import '@nomiclabs/hardhat-ethers';
import { expect } from 'chai';
import { parseEther } from 'ethers/lib/utils';
import { ZERO_ADDRESS } from '../../helpers/constants';
import { ERRORS } from '../../helpers/errors';
import {
  FIRST_PROFILE_ID,
  governance,
  lensHub,
  makeSuiteCleanRoom,
  MOCK_FOLLOW_NFT_URI,
  MOCK_PROFILE_HANDLE,
  MOCK_PROFILE_URI,
  erc721FollowModule,
  userAddress,
  userTwo,
  genericNFT,
  abiCoder,
} from '../../__setup.spec';

makeSuiteCleanRoom('ERC721 Gated Follow Module', function () {
  beforeEach(async function () {
    await expect(
      lensHub.createProfile({
        to: userAddress,
        handle: MOCK_PROFILE_HANDLE,
        imageURI: MOCK_PROFILE_URI,
        followModule: ZERO_ADDRESS,
        followModuleInitData: [],
        followNFTURI: MOCK_FOLLOW_NFT_URI,
      })
    ).to.not.be.reverted;
    await expect(
      lensHub.connect(governance).whitelistFollowModule(erc721FollowModule.address, true)
    ).to.not.be.reverted;
  });

  context('Negatives', function () {
    context('Initialization', function () {
      it('Initialize call should fail when sender is not the hub', async function () {
        await expect(
          erc721FollowModule.initializeFollowModule(FIRST_PROFILE_ID, [])
        ).to.be.revertedWith(ERRORS.NOT_HUB);
      });
    });

    context('Processing follow', function () {
      it.only('UserTwo should fail to process follow if the user does not own the NFT', async function () {
        const data = abiCoder.encode(['address'], [genericNFT.address]);
        await lensHub.setFollowModule(FIRST_PROFILE_ID, erc721FollowModule.address, data);
        expect(await lensHub.getFollowModule(FIRST_PROFILE_ID)).to.be.equal(
          erc721FollowModule.address
        );

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.reverted;
      });
    });
  });

  context('Scenarios', function () {
    context('Initialization', function () {
      it('Initialize call should succeed when passing non empty data and return empty bytes', async function () {
        const nonEmptyData = '0x1234';
        expect(
          await erc721FollowModule
            .connect(lensHub.address)
            .initializeFollowModule(FIRST_PROFILE_ID, nonEmptyData)
        ).to.be.equals('0x');
      });
    });

    context('Processing follow', function () {
      it.only('UserTwo should be able to follow if the user owns the NFT', async function () {
        const data = abiCoder.encode(['address'], [genericNFT.address]);
        await lensHub.setFollowModule(FIRST_PROFILE_ID, erc721FollowModule.address, data);
        expect(await lensHub.getFollowModule(FIRST_PROFILE_ID)).to.be.equal(
          erc721FollowModule.address
        );

        expect(await erc721FollowModule.nftByProfile(FIRST_PROFILE_ID)).to.equal(genericNFT.address);

        await genericNFT.connect(userTwo).mint();

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
      });
    });
  });
});
