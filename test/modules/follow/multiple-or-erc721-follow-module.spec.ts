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
  multipleOrErc721FollowModule,
  userAddress,
  userTwo,
  myNFT,
  abiCoder,
  myNFT2,
  myNFT3,
} from '../../__setup.spec';

makeSuiteCleanRoom('Multiple OR ERC721 Gated Follow Module', function () {
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
      lensHub.connect(governance).whitelistFollowModule(multipleOrErc721FollowModule.address, true)
    ).to.not.be.reverted;
  });

  context('Negatives', function () {
    context('Initialization', function () {
      it('Initialize call should fail when sender is not the hub', async function () {
        await expect(
          multipleOrErc721FollowModule.initializeFollowModule(FIRST_PROFILE_ID, [])
        ).to.be.revertedWith(ERRORS.NOT_HUB);
      });
    });

    context('Processing follow', function () {
      it.only('User should fail to process follow if the user does not own any of the NFTs', async function () {
        const data = abiCoder.encode(
          ['address[]'],
          [[myNFT.address, myNFT2.address, myNFT3.address]]
        );
        await lensHub.setFollowModule(FIRST_PROFILE_ID, multipleOrErc721FollowModule.address, data);
        expect(await lensHub.getFollowModule(FIRST_PROFILE_ID)).to.be.equal(
          multipleOrErc721FollowModule.address
        );

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.revertedWith(
          'INSUFFICIENT_NFT_BALANCE'
        );
      });
    });
  });

  context('Scenarios', function () {
    context('Initialization', function () {
      it('Initialize call should succeed when passing non empty data and return empty bytes', async function () {
        const nonEmptyData = '0x1234';
        expect(
          await multipleOrErc721FollowModule
            .connect(lensHub.address)
            .initializeFollowModule(FIRST_PROFILE_ID, nonEmptyData)
        ).to.be.equals('0x');
      });
    });

    context('Processing follow', function () {
      it.only('UserTwo should be able to follow if the user owns all the NFTs', async function () {
        const data = abiCoder.encode(
          ['address[]'],
          [[myNFT.address, myNFT2.address, myNFT3.address]]
        );
        await lensHub.setFollowModule(FIRST_PROFILE_ID, multipleOrErc721FollowModule.address, data);
        expect(await lensHub.getFollowModule(FIRST_PROFILE_ID)).to.be.equal(
          multipleOrErc721FollowModule.address
        );

        expect(await multipleOrErc721FollowModule.getNfts(FIRST_PROFILE_ID)).to.have.members([
          myNFT.address,
          myNFT2.address,
          myNFT3.address,
        ]);

        await myNFT.connect(userTwo).mint();
        await myNFT2.connect(userTwo).mint();
        await myNFT3.connect(userTwo).mint();

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
      });

      it.only('User should be able to follow if the user owns some but not all of the NFTs', async function () {
        const data = abiCoder.encode(
          ['address[]'],
          [[myNFT.address, myNFT2.address, myNFT3.address]]
        );
        await lensHub.setFollowModule(FIRST_PROFILE_ID, multipleOrErc721FollowModule.address, data);
        expect(await lensHub.getFollowModule(FIRST_PROFILE_ID)).to.be.equal(
          multipleOrErc721FollowModule.address
        );

        expect(await multipleOrErc721FollowModule.getNfts(FIRST_PROFILE_ID)).to.have.members([
          myNFT.address,
          myNFT2.address,
          myNFT3.address,
        ]);

        await myNFT3.connect(userTwo).mint();

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
      });
    });
  });
});
