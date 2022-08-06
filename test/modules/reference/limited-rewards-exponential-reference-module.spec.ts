import '@nomiclabs/hardhat-ethers';
import { expect } from 'chai';
import { formatEther, parseEther } from 'ethers/lib/utils';
import { FollowNFT__factory } from '../../../typechain-types';
import { ZERO_ADDRESS } from '../../helpers/constants';
import { ERRORS } from '../../helpers/errors';
import { getTimestamp, matchEvent, waitForTx } from '../../helpers/utils';
import {
  freeCollectModule,
  FIRST_PROFILE_ID,
  limitedRewardsExponentialReferenceModule,
  governance,
  lensHub,
  makeSuiteCleanRoom,
  MOCK_FOLLOW_NFT_URI,
  MOCK_PROFILE_HANDLE,
  MOCK_PROFILE_URI,
  MOCK_URI,
  user,
  userAddress,
  userThreeAddress,
  userTwo,
  userTwoAddress,
  abiCoder,
  token,
  moduleGlobals,
  followerOnlyReferenceModule,
  userThree,
} from '../../__setup.spec';

makeSuiteCleanRoom('Limited Rewards Exponential Reference Module', function () {
  const SECOND_PROFILE_ID = FIRST_PROFILE_ID + 1;
  const THIRD_PROFILE_ID = SECOND_PROFILE_ID + 1;

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
      lensHub.createProfile({
        to: userTwoAddress,
        handle: 'user2',
        imageURI: MOCK_PROFILE_URI,
        followModule: ZERO_ADDRESS,
        followModuleInitData: [],
        followNFTURI: MOCK_FOLLOW_NFT_URI,
      })
    ).to.not.be.reverted;
    await expect(
      lensHub
        .connect(governance)
        .whitelistReferenceModule(followerOnlyReferenceModule.address, true)
    ).to.not.be.reverted;
    await expect(
      lensHub
        .connect(governance)
        .whitelistReferenceModule(limitedRewardsExponentialReferenceModule.address, true)
    ).to.not.be.reverted;
    await expect(
      lensHub.connect(governance).whitelistCollectModule(freeCollectModule.address, true)
    ).to.not.be.reverted;

    await expect(
      moduleGlobals.connect(governance).whitelistCurrency(token.address, true)
    ).to.not.be.reverted;

    // await expect(
    //   lensHub.post({
    //     profileId: FIRST_PROFILE_ID,
    //     contentURI: MOCK_URI,
    //     collectModule: freeCollectModule.address,
    //     collectModuleInitData: abiCoder.encode(['bool'], [true]),
    //     referenceModule: followerOnlyReferenceModule.address,
    //     referenceModuleInitData: [],
    //   })
    // ).to.not.be.reverted;
    const tokenAmount = parseEther('10000');
    const mirrorLimit = parseEther('100');

    // Token Amount, Mirror Limit, Token Address, Follower only
    const data = abiCoder.encode(
      ['uint256', 'uint256', 'address', 'bool'],
      [tokenAmount, mirrorLimit, token.address, false]
    );

    await token.connect(user).mint(parseEther('100000'));

    await expect(
      token.connect(user).approve(limitedRewardsExponentialReferenceModule.address, tokenAmount)
    ).to.not.be.reverted;

    await expect(
      lensHub.post({
        profileId: FIRST_PROFILE_ID,
        contentURI: MOCK_URI,
        collectModule: freeCollectModule.address,
        collectModuleInitData: abiCoder.encode(['bool'], [true]),
        referenceModule: limitedRewardsExponentialReferenceModule.address,
        referenceModuleInitData: data,
      })
    ).to.not.be.reverted;
  });

  context('Negatives', function () {
    // TODO: We need a `publishing` or `initialization` context too because initialization can revert in the limitedRewardsExponentialReferenceModule.
    context('Commenting', function () {
      it('Commenting should fail if commenter is not a follower and follow NFT not yet deployed', async function () {
        await expect(
          lensHub.connect(userTwo).comment({
            profileId: SECOND_PROFILE_ID,
            contentURI: MOCK_URI,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            collectModule: freeCollectModule.address,
            collectModuleInitData: abiCoder.encode(['bool'], [true]),
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.be.revertedWith(ERRORS.FOLLOW_INVALID);
      });

      it('Commenting should fail if commenter follows, then transfers the follow NFT before attempting to comment', async function () {
        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          followNFT.connect(userTwo).transferFrom(userTwoAddress, userThreeAddress, 1)
        ).to.not.be.reverted;

        await expect(
          lensHub.connect(userTwo).comment({
            profileId: SECOND_PROFILE_ID,
            contentURI: MOCK_URI,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            collectModule: freeCollectModule.address,
            collectModuleInitData: abiCoder.encode(['bool'], [true]),
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.be.revertedWith(ERRORS.FOLLOW_INVALID);
      });
    });

    context('Mirroring', function () {
      it('Mirroring should fail if mirrorer is not a follower and follow NFT not yet deployed', async function () {
        await expect(
          lensHub.connect(userTwo).mirror({
            profileId: SECOND_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.be.revertedWith(ERRORS.FOLLOW_INVALID);
      });

      it('Mirroring should fail if mirrorer follows, then transfers the follow NFT before attempting to mirror', async function () {
        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          followNFT.connect(userTwo).transferFrom(userTwoAddress, userAddress, 1)
        ).to.not.be.reverted;

        await expect(
          lensHub.connect(userTwo).mirror({
            profileId: SECOND_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.be.revertedWith(ERRORS.FOLLOW_INVALID);
      });

      it.only('Mirroring should fail if attempted more than once', async function () {
        await expect(lensHub.follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;

        const initialAmount = +formatEther(await token.balanceOf(await userTwo.getAddress()));
        console.log({ initialAmount });

        await expect(
          lensHub.connect(userTwo).mirror({
            profileId: SECOND_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;

        await expect(
          lensHub.connect(userTwo).mirror({
            profileId: SECOND_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.be.reverted;

        // const publicationData = await limitedRewardsExponentialReferenceModule.getPublicationData(1, 1);

        // const totalRewardAmount = publicationData.amount;
        // const mirrorLimit = publicationData.mirrorLimit;
        // const rewardAmount = +formatEther(totalRewardAmount.div(mirrorLimit)) * 10 ** 18;

        const finalAmount = +formatEther(await token.balanceOf(await userTwo.getAddress()));
        console.log({ finalAmount });

        // expect(finalAmount).to.equal(rewardAmount);
      });
    });
  });

  context('Scenarios', function () {
    context('Publishing', function () {
      it('Posting with follower only reference module as reference module should emit expected events', async function () {
        const tx = lensHub.post({
          profileId: FIRST_PROFILE_ID,
          contentURI: MOCK_URI,
          collectModule: freeCollectModule.address,
          collectModuleInitData: abiCoder.encode(['bool'], [true]),
          referenceModule: limitedRewardsExponentialReferenceModule.address,
          referenceModuleInitData: [],
        });
        const receipt = await waitForTx(tx);

        expect(receipt.logs.length).to.eq(1);
        matchEvent(receipt, 'PostCreated', [
          FIRST_PROFILE_ID,
          2,
          MOCK_URI,
          freeCollectModule.address,
          abiCoder.encode(['bool'], [true]),
          limitedRewardsExponentialReferenceModule.address,
          [],
          await getTimestamp(),
        ]);
      });
    });

    context('Commenting', function () {
      it('Commenting should work if the commenter is a follower', async function () {
        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          lensHub.connect(userTwo).comment({
            profileId: SECOND_PROFILE_ID,
            contentURI: MOCK_URI,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            collectModule: freeCollectModule.address,
            collectModuleInitData: abiCoder.encode(['bool'], [true]),
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Commenting should work if the commenter is the publication owner and he is following himself', async function () {
        await expect(lensHub.follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          lensHub.comment({
            profileId: FIRST_PROFILE_ID,
            contentURI: MOCK_URI,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            collectModule: freeCollectModule.address,
            collectModuleInitData: abiCoder.encode(['bool'], [true]),
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Commenting should work if the commenter is the publication owner even when he is not following himself and follow NFT was not deployed', async function () {
        await expect(
          lensHub.comment({
            profileId: FIRST_PROFILE_ID,
            contentURI: MOCK_URI,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            collectModule: freeCollectModule.address,
            collectModuleInitData: abiCoder.encode(['bool'], [true]),
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Commenting should work if the commenter is the publication owner even when he is not following himself and follow NFT was deployed', async function () {
        await expect(lensHub.follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(followNFT.transferFrom(userAddress, userTwoAddress, 1)).to.not.be.reverted;

        await expect(
          lensHub.comment({
            profileId: FIRST_PROFILE_ID,
            contentURI: MOCK_URI,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            collectModule: freeCollectModule.address,
            collectModuleInitData: abiCoder.encode(['bool'], [true]),
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Commenting should work if the commenter follows, transfers the follow NFT then receives it back before attempting to comment', async function () {
        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          followNFT.connect(userTwo).transferFrom(userTwoAddress, userAddress, 1)
        ).to.not.be.reverted;

        await expect(followNFT.transferFrom(userAddress, userTwoAddress, 1)).to.not.be.reverted;

        await expect(
          lensHub.connect(userTwo).comment({
            profileId: SECOND_PROFILE_ID,
            contentURI: MOCK_URI,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            collectModule: freeCollectModule.address,
            collectModuleInitData: abiCoder.encode(['bool'], [true]),
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });
    });

    context('Mirroring', function () {
      it('Mirroring should work if mirrorer is a follower', async function () {
        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          lensHub.connect(userTwo).mirror({
            profileId: SECOND_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Mirroring should work if mirrorer follows, transfers the follow NFT then receives it back before attempting to mirror', async function () {
        await expect(lensHub.connect(userTwo).follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          followNFT.connect(userTwo).transferFrom(userTwoAddress, userAddress, 1)
        ).to.not.be.reverted;

        await expect(followNFT.transferFrom(userAddress, userTwoAddress, 1)).to.not.be.reverted;

        await expect(
          lensHub.connect(userTwo).mirror({
            profileId: SECOND_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Mirroring should work if the mirrorer is the publication owner and he is following himself', async function () {
        await expect(lensHub.follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(
          lensHub.mirror({
            profileId: FIRST_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Mirroring should work if the mirrorer is the publication owner even when he is not following himself and follow NFT was not deployed', async function () {
        await expect(
          lensHub.mirror({
            profileId: FIRST_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it('Mirroring should work if the mirrorer is the publication owner even when he is not following himself and follow NFT was deployed', async function () {
        await expect(lensHub.follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;
        const followNFT = FollowNFT__factory.connect(
          await lensHub.getFollowNFT(FIRST_PROFILE_ID),
          user
        );

        await expect(followNFT.transferFrom(userAddress, userTwoAddress, 1)).to.not.be.reverted;

        await expect(
          lensHub.mirror({
            profileId: FIRST_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.not.be.reverted;
      });

      it.only('User should receive a calculated amount of tokens on mirroring the publication', async function () {
        await expect(lensHub.follow([FIRST_PROFILE_ID], [[]])).to.not.be.reverted;

        const initialAmount = +formatEther(await token.balanceOf(await userTwo.getAddress()));
        console.log({ initialAmount });

        await expect(
          lensHub.connect(userTwo).mirror({
            profileId: SECOND_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.be.revertedWith('YAY');

        await expect(
          lensHub.connect(userThree).mirror({
            profileId: THIRD_PROFILE_ID,
            profileIdPointed: FIRST_PROFILE_ID,
            pubIdPointed: 1,
            referenceModuleData: [],
            referenceModule: ZERO_ADDRESS,
            referenceModuleInitData: [],
          })
        ).to.be.revertedWith('YAY');

        const balanceUser3 = +formatEther(await token.balanceOf(await userThree.getAddress()));
        console.log({ balanceUser3 });

        // const publicationData = await limitedRewardsExponentialReferenceModule.getPublicationData(1, 1);

        // const totalRewardAmount = publicationData.amount;
        // const mirrorLimit = publicationData.mirrorLimit;
        // const rewardAmount = +formatEther(totalRewardAmount.div(mirrorLimit)) * 10 ** 18;

        const finalAmount = +formatEther(await token.balanceOf(await userTwo.getAddress()));
        console.log({ finalAmount });

        // expect(finalAmount).to.equal(rewardAmount);
      });
    });
  });
});
