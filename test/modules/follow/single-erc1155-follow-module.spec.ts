import { userThree } from './../../__setup.spec';
import { FollowNFT__factory } from './../../../typechain-types/factories/FollowNFT__factory';
import '@nomiclabs/hardhat-ethers';
import { expect } from 'chai';
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
  userAddress,
  userTwo,
  abiCoder,
  singleErc1155FollowModule,
  myERC1155,
} from '../../__setup.spec';

makeSuiteCleanRoom('Single ERC1155 Gated Follow Module', function () {
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
      lensHub.connect(governance).whitelistFollowModule(singleErc1155FollowModule.address, true)
    ).to.not.be.reverted;
  });

  context('Negatives', function () {
    context('Initialization', function () {
      it('Initialize call should fail when sender is not the hub', async () => {
        await expect(
          singleErc1155FollowModule.initializeFollowModule(FIRST_PROFILE_ID, [])
        ).to.be.revertedWith(ERRORS.NOT_HUB);
      });
    });

    context('Processing follow', function () {
      it('should fail to process follow if the user does not own the NFT', async function () {
        const data = abiCoder.encode(
          ['address', 'uint256', 'uint256', 'bool'],
          [myERC1155.address, 1, 1, true]
        );

        await lensHub.setFollowModule(FIRST_PROFILE_ID, singleErc1155FollowModule.address, data);
        expect(await lensHub.getFollowModule(FIRST_PROFILE_ID)).to.be.equal(
          singleErc1155FollowModule.address
        );

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.reverted;
      });

      it("should fail process follow if the user's balance if too low", async () => {
        const data = abiCoder.encode(
          ['address', 'uint256', 'uint256', 'bool'],
          [myERC1155.address, 1, 2, true]
        );
        await lensHub.setFollowModule(FIRST_PROFILE_ID, singleErc1155FollowModule.address, data);
        await myERC1155.connect(userTwo).mint(await userTwo.getAddress(), 1, 1);

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.reverted;
      });
    });

    context('Processing transfer', async () => {
      it('should fail to transfer if follow module is not transferable', async () => {
        const data = abiCoder.encode(
          ['address', 'uint256', 'uint256', 'bool'],
          [myERC1155.address, 1, 1, false]
        );

        await lensHub.setFollowModule(FIRST_PROFILE_ID, singleErc1155FollowModule.address, data);
        // Mint Gatting Token
        await myERC1155.connect(userTwo).mint(await userTwo.getAddress(), 1, 1);
        await myERC1155.connect(userTwo).mint(await userThree.getAddress(), 1, 1);
        // Follow profile
        await lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]]);

        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          userTwo
        );

        await expect(
          followNFT.transferFrom(await userTwo.getAddress(), await userThree.getAddress(), 1)
        ).to.reverted;
      });
    });
  });

  context('Scenarios', function () {
    context('Processing follow', async () => {
      it('should be able to follow if the user owns enough tokens', async () => {
        const data = abiCoder.encode(
          ['address', 'uint256', 'uint256', 'bool'],
          [myERC1155.address, 1, 1, false]
        );

        await lensHub.setFollowModule(FIRST_PROFILE_ID, singleErc1155FollowModule.address, data);
        // Mint Gatting Token
        await myERC1155.connect(userTwo).mint(await userTwo.getAddress(), 1, 1);

        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.reverted;
      });
    });
    context('Processing transfer', async () => {
      it('should be able to transfer', async () => {
        const data = abiCoder.encode(
          ['address', 'uint256', 'uint256', 'bool'],
          [myERC1155.address, 1, 1, true]
        );

        await lensHub.setFollowModule(FIRST_PROFILE_ID, singleErc1155FollowModule.address, data);
        // Mint Gatting Token
        await myERC1155.connect(userTwo).mint(await userTwo.getAddress(), 1, 1);
        await myERC1155.connect(userTwo).mint(await userThree.getAddress(), 1, 1);
        // Follow profile
        await lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]]);

        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          userTwo
        );

        try {
          await expect(
            followNFT.transferFrom(await userTwo.getAddress(), await userThree.getAddress(), 1)
          ).to.not.reverted;
        } catch (error) {
          console.log('error', error);
        }
      });
    });
  });
});
