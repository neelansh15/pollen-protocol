import { defaultAbiCoder } from 'ethers/lib/utils';
import { task } from 'hardhat/config';
import { FollowNFT__factory, LensHub__factory, MyFollowModule__factory } from '../typechain-types';
import { CreateProfileDataStruct } from '../typechain-types/LensHub';
import {
  waitForTx,
  initEnv,
  getAddrs,
  ProtocolState,
  ZERO_ADDRESS,
  deployContract,
} from './helpers/utils';

task('test-module', 'tests the MyFollowModule').setAction(async ({}, hre) => {
  const [governance, user] = await initEnv(hre);
  const addresses = getAddrs();

  const lensHub = LensHub__factory.connect(addresses['lensHub proxy'], governance);

  await waitForTx(lensHub.setState(ProtocolState.Unpaused));
  await waitForTx(lensHub.whitelistProfileCreator(user.address, true));

  const profile: CreateProfileDataStruct = {
    to: user.address,
    handle: 'alkibiadez',
    followModule: ZERO_ADDRESS,
    followModuleInitData: [],
    followNFTURI:
      'https://lh3.googleusercontent.com/ebT3cST8Mh9Db7l8MhxhuBio1R-z3rOUPGeTAqyIaeymyQKvXDNHg9sHfzM6NefaKmCj33RtAfSIL7qNz2xM-6i_7aM0cOZvCrhigA=w600',
    imageURI:
      'https://lh3.googleusercontent.com/ebT3cST8Mh9Db7l8MhxhuBio1R-z3rOUPGeTAqyIaeymyQKvXDNHg9sHfzM6NefaKmCj33RtAfSIL7qNz2xM-6i_7aM0cOZvCrhigA=w600',
  };

  await waitForTx(lensHub.connect(user).createProfile(profile));

  // Custom Follow Module Created and Set
  const myfollowmodule = await deployContract(
    new MyFollowModule__factory(governance).deploy(lensHub.address)
  );

  await waitForTx(lensHub.whitelistFollowModule(myfollowmodule.address, true));

  const data = defaultAbiCoder.encode(['uint256'], ['42069']);
  await waitForTx(lensHub.connect(user).setFollowModule(1, myfollowmodule.address, data));

  // Use the custom Follow Module

  const badData = defaultAbiCoder.encode(['uint256'], ['41968']);
  try {
    await waitForTx(lensHub.connect(user).follow([1], [badData]));
  } catch (e) {
    console.error('Error while following, likely Invalid Passcode', e);
  }

  const goodData = defaultAbiCoder.encode(['uint256'], ['42069']);
  try {
    await waitForTx(lensHub.connect(user).follow([1], [goodData]));
  } catch (e) {
    console.error('Error while following. Weird, it should work', e);
  }

  // Confirm that the follow worked
  const followNFTAddr = await lensHub.getFollowNFT(1);
  const followNFT = FollowNFT__factory.connect(followNFTAddr, user);

  const totalSupply = await followNFT.totalSupply();
  const ownerOf = await followNFT.ownerOf(1);

  console.log('Follow NFT total supply (should be 1): ', totalSupply);
  console.log(`Owner of 1st nft is ${ownerOf} which should be the same as user ${user.address}`);
});
