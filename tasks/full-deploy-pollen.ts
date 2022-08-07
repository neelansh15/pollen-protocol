import '@nomiclabs/hardhat-ethers';
import { hexlify, keccak256, RLP } from 'ethers/lib/utils';
import fs from 'fs';
import { task } from 'hardhat/config';
import {
  LensHub__factory,
  ApprovalFollowModule__factory,
  CollectNFT__factory,
  Currency__factory,
  FreeCollectModule__factory,
  FeeCollectModule__factory,
  FeeFollowModule__factory,
  ERC721GateFollowModule__factory,
  MultipleAndERC721GateFollowModule__factory,
  MultipleOrERC721GateFollowModule__factory,
  ProfilesGateAndFollowModule__factory,
  ProfilesGateOrFollowModule__factory,
  FollowerOnlyReferenceModule__factory,
  LimitedRewardReferenceModule__factory,
  LimitedRewardsExponentialReferenceModule__factory,
  FollowNFT__factory,
  InteractionLogic__factory,
  LimitedFeeCollectModule__factory,
  LimitedTimedFeeCollectModule__factory,
  ModuleGlobals__factory,
  PublishingLogic__factory,
  RevertCollectModule__factory,
  TimedFeeCollectModule__factory,
  TransparentUpgradeableProxy__factory,
  ProfileTokenURILogic__factory,
  LensPeriphery__factory,
  UIDataProvider__factory,
  ProfileFollowModule__factory,
  RevertFollowModule__factory,
  ProfileCreationProxy__factory,
} from '../typechain-types';
import { deployContract, waitForTx } from './helpers/utils';

const TREASURY_FEE_BPS = 50;
const LENS_HUB_NFT_NAME = 'Lens Protocol Profiles';
const LENS_HUB_NFT_SYMBOL = 'LPP';

task('full-deploy-pollen', 'deploys the entire Lens Protocol').setAction(async ({}, hre) => {
  // Note that the use of these signers is a placeholder and is not meant to be used in
  // production.
  const ethers = hre.ethers;
  const accounts = await ethers.getSigners();
  console.log(accounts.map((acc) => acc.address));
  const deployer = accounts[0];
  const governance = accounts[1];
  const treasuryAddress = accounts[2].address;
  const proxyAdminAddress = deployer.address;
  const profileCreatorAddress = deployer.address;

  // Nonce management in case of deployment issues
  let deployerNonce = await ethers.provider.getTransactionCount(deployer.address);

  console.log('\n\t-- Deploying Module Globals --');
  const moduleGlobals = await deployContract(
    new ModuleGlobals__factory(deployer).deploy(
      governance.address,
      treasuryAddress,
      TREASURY_FEE_BPS,
      { nonce: deployerNonce++ }
    )
  );

  console.log('\n\t-- Deploying Logic Libs --');

  const publishingLogic = await deployContract(
    new PublishingLogic__factory(deployer).deploy({ nonce: deployerNonce++ })
  );
  const interactionLogic = await deployContract(
    new InteractionLogic__factory(deployer).deploy({ nonce: deployerNonce++ })
  );
  const profileTokenURILogic = await deployContract(
    new ProfileTokenURILogic__factory(deployer).deploy({ nonce: deployerNonce++ })
  );
  const hubLibs = {
    'contracts/libraries/PublishingLogic.sol:PublishingLogic': publishingLogic.address,
    'contracts/libraries/InteractionLogic.sol:InteractionLogic': interactionLogic.address,
    'contracts/libraries/ProfileTokenURILogic.sol:ProfileTokenURILogic':
      profileTokenURILogic.address,
  };

  // Here, we pre-compute the nonces and addresses used to deploy the contracts.
  // const nonce = await deployer.getTransactionCount();
  const followNFTNonce = hexlify(deployerNonce + 1);
  const collectNFTNonce = hexlify(deployerNonce + 2);
  const hubProxyNonce = hexlify(deployerNonce + 3);

  const followNFTImplAddress =
    '0x' + keccak256(RLP.encode([deployer.address, followNFTNonce])).substr(26);
  const collectNFTImplAddress =
    '0x' + keccak256(RLP.encode([deployer.address, collectNFTNonce])).substr(26);
  const hubProxyAddress =
    '0x' + keccak256(RLP.encode([deployer.address, hubProxyNonce])).substr(26);

  // Next, we deploy first the hub implementation, then the followNFT implementation, the collectNFT, and finally the
  // hub proxy with initialization.
  console.log('\n\t-- Deploying Hub Implementation --');

  const lensHubImpl = await deployContract(
    new LensHub__factory(hubLibs, deployer).deploy(followNFTImplAddress, collectNFTImplAddress, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying Follow & Collect NFT Implementations --');
  await deployContract(
    new FollowNFT__factory(deployer).deploy(hubProxyAddress, { nonce: deployerNonce++ })
  );
  await deployContract(
    new CollectNFT__factory(deployer).deploy(hubProxyAddress, { nonce: deployerNonce++ })
  );

  let data = lensHubImpl.interface.encodeFunctionData('initialize', [
    LENS_HUB_NFT_NAME,
    LENS_HUB_NFT_SYMBOL,
    governance.address,
  ]);

  console.log('\n\t-- Deploying Hub Proxy --');
  let proxy = await deployContract(
    new TransparentUpgradeableProxy__factory(deployer).deploy(
      lensHubImpl.address,
      proxyAdminAddress,
      data,
      { nonce: deployerNonce++ }
    )
  );

  // Connect the hub proxy to the LensHub factory and the governance for ease of use.
  const lensHub = LensHub__factory.connect(proxy.address, governance);

  console.log('\n\t-- Deploying Lens Periphery --');
  const lensPeriphery = await new LensPeriphery__factory(deployer).deploy(lensHub.address, {
    nonce: deployerNonce++,
  });

  // Currency
  console.log('\n\t-- Deploying Currency --');
  const currency = await deployContract(
    new Currency__factory(deployer).deploy({ nonce: deployerNonce++ })
  );

  // Deploy collect modules
  console.log('\n\t-- Deploying feeCollectModule --');
  const feeCollectModule = await deployContract(
    new FeeCollectModule__factory(deployer).deploy(lensHub.address, moduleGlobals.address, {
      nonce: deployerNonce++,
    })
  );
  console.log('\n\t-- Deploying limitedFeeCollectModule --');
  const limitedFeeCollectModule = await deployContract(
    new LimitedFeeCollectModule__factory(deployer).deploy(lensHub.address, moduleGlobals.address, {
      nonce: deployerNonce++,
    })
  );
  console.log('\n\t-- Deploying timedFeeCollectModule --');
  const timedFeeCollectModule = await deployContract(
    new TimedFeeCollectModule__factory(deployer).deploy(lensHub.address, moduleGlobals.address, {
      nonce: deployerNonce++,
    })
  );
  console.log('\n\t-- Deploying limitedTimedFeeCollectModule --');
  const limitedTimedFeeCollectModule = await deployContract(
    new LimitedTimedFeeCollectModule__factory(deployer).deploy(
      lensHub.address,
      moduleGlobals.address,
      { nonce: deployerNonce++ }
    )
  );

  console.log('\n\t-- Deploying revertCollectModule --');
  const revertCollectModule = await deployContract(
    new RevertCollectModule__factory(deployer).deploy({ nonce: deployerNonce++ })
  );
  console.log('\n\t-- Deploying freeCollectModule --');
  const freeCollectModule = await deployContract(
    new FreeCollectModule__factory(deployer).deploy(lensHub.address, { nonce: deployerNonce++ })
  );

  // Deploy follow modules
  console.log('\n\t-- Deploying feeFollowModule --');
  const feeFollowModule = await deployContract(
    new FeeFollowModule__factory(deployer).deploy(lensHub.address, moduleGlobals.address, {
      nonce: deployerNonce++,
    })
  );
  console.log('\n\t-- Deploying profileFollowModule --');
  const profileFollowModule = await deployContract(
    new ProfileFollowModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );
  console.log('\n\t-- Deploying revertFollowModule --');
  const revertFollowModule = await deployContract(
    new RevertFollowModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying erc721GateFollowModule --');
  const erc721GateFollowModule = await deployContract(
    new ERC721GateFollowModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying multipleAndERC721GateFollowModule --');
  const multipleAndERC721GateFollowModule = await deployContract(
    new MultipleAndERC721GateFollowModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying erc721multipleOrERC721GateFollowModuleGateFollowModule --');
  const multipleOrERC721GateFollowModule = await deployContract(
    new MultipleOrERC721GateFollowModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying ProfilesGateAndFollowModule --');
  const profilesGateAndFollowModule = await deployContract(
    new ProfilesGateAndFollowModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying ProfilesGateOrFollowModule --');
  const profilesGateOrFollowModule = await deployContract(
    new ProfilesGateOrFollowModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  // --- COMMENTED OUT AS THIS IS NOT A LAUNCH MODULE ---
  // console.log('\n\t-- Deploying approvalFollowModule --');
  // const approvalFollowModule = await deployContract(
  //   new ApprovalFollowModule__factory(deployer).deploy(lensHub.address, { nonce: deployerNonce++ })
  // );

  // Deploy reference module
  console.log('\n\t-- Deploying followerOnlyReferenceModule --');
  const followerOnlyReferenceModule = await deployContract(
    new FollowerOnlyReferenceModule__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying LimitedRewardsReferenceModule --');
  const limitedRewardsReferenceModule = await deployContract(
    new LimitedRewardReferenceModule__factory(deployer).deploy(
      lensHub.address,
      moduleGlobals.address,
      {
        nonce: deployerNonce++,
      }
    )
  );

  console.log('\n\t-- Deploying LimitedRewardsExponentialReferenceModule --');
  const limitedRewardsExponentialReferenceModule = await deployContract(
    new LimitedRewardsExponentialReferenceModule__factory(deployer).deploy(
      lensHub.address,
      moduleGlobals.address,
      {
        nonce: deployerNonce++,
      }
    )
  );

  // Deploy UIDataProvider
  console.log('\n\t-- Deploying UI Data Provider --');
  const uiDataProvider = await deployContract(
    new UIDataProvider__factory(deployer).deploy(lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  console.log('\n\t-- Deploying Profile Creation Proxy --');
  const profileCreationProxy = await deployContract(
    new ProfileCreationProxy__factory(deployer).deploy(profileCreatorAddress, lensHub.address, {
      nonce: deployerNonce++,
    })
  );

  // Whitelist the collect modules
  console.log('\n\t-- Whitelisting Collect Modules --');
  let governanceNonce = await ethers.provider.getTransactionCount(governance.address);
  await waitForTx(
    lensHub.whitelistCollectModule(feeCollectModule.address, true, { nonce: governanceNonce++ })
  );
  await waitForTx(
    lensHub.whitelistCollectModule(limitedFeeCollectModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistCollectModule(timedFeeCollectModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistCollectModule(limitedTimedFeeCollectModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistCollectModule(revertCollectModule.address, true, { nonce: governanceNonce++ })
  );
  await waitForTx(
    lensHub.whitelistCollectModule(freeCollectModule.address, true, { nonce: governanceNonce++ })
  );

  // Whitelist the follow modules
  console.log('\n\t-- Whitelisting Follow Modules --');
  await waitForTx(
    lensHub.whitelistFollowModule(feeFollowModule.address, true, { nonce: governanceNonce++ })
  );
  await waitForTx(
    lensHub.whitelistFollowModule(profileFollowModule.address, true, { nonce: governanceNonce++ })
  );
  await waitForTx(
    lensHub.whitelistFollowModule(revertFollowModule.address, true, { nonce: governanceNonce++ })
  );
  await waitForTx(
    lensHub.whitelistFollowModule(erc721GateFollowModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistFollowModule(multipleAndERC721GateFollowModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistFollowModule(multipleOrERC721GateFollowModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistFollowModule(profilesGateAndFollowModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistFollowModule(profilesGateOrFollowModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  // --- COMMENTED OUT AS THIS IS NOT A LAUNCH MODULE ---
  // await waitForTx(
  // lensHub.whitelistFollowModule(approvalFollowModule.address, true, { nonce: governanceNonce++ })
  // );

  // Whitelist the reference module
  console.log('\n\t-- Whitelisting Reference Module --');
  await waitForTx(
    lensHub.whitelistReferenceModule(followerOnlyReferenceModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistReferenceModule(limitedRewardsReferenceModule.address, true, {
      nonce: governanceNonce++,
    })
  );
  await waitForTx(
    lensHub.whitelistReferenceModule(limitedRewardsExponentialReferenceModule.address, true, {
      nonce: governanceNonce++,
    })
  );

  // Whitelist the currency
  console.log('\n\t-- Whitelisting Currency in Module Globals --');
  await waitForTx(
    moduleGlobals
      .connect(governance)
      .whitelistCurrency(currency.address, true, { nonce: governanceNonce++ })
  );

  // Whitelist the profile creation proxy
  console.log('\n\t-- Whitelisting Profile Creation Proxy --');
  await waitForTx(
    lensHub.whitelistProfileCreator(profileCreationProxy.address, true, {
      nonce: governanceNonce++,
    })
  );

  // Save and log the addresses
  const addrs = {
    'lensHub proxy': lensHub.address,
    'lensHub impl:': lensHubImpl.address,
    'publishing logic lib': publishingLogic.address,
    'interaction logic lib': interactionLogic.address,
    'follow NFT impl': followNFTImplAddress,
    'collect NFT impl': collectNFTImplAddress,
    currency: currency.address,
    'lens periphery': lensPeriphery.address,
    'module globals': moduleGlobals.address,
    'fee collect module': feeCollectModule.address,
    'limited fee collect module': limitedFeeCollectModule.address,
    'timed fee collect module': timedFeeCollectModule.address,
    'limited timed fee collect module': limitedTimedFeeCollectModule.address,
    'revert collect module': revertCollectModule.address,
    'free collect module': freeCollectModule.address,
    'fee follow module': feeFollowModule.address,
    'profile follow module': profileFollowModule.address,
    'revert follow module': revertFollowModule.address,
    // --- COMMENTED OUT AS THIS IS NOT A LAUNCH MODULE ---
    // 'approval follow module': approvalFollowModule.address,
    'follower only reference module': followerOnlyReferenceModule.address,
    'UI data provider': uiDataProvider.address,
    'Profile creation proxy': profileCreationProxy.address,
    // Pollen
    'erc721 gated follow module': erc721GateFollowModule.address,
    'multiple and erc721 gated follow module': multipleAndERC721GateFollowModule.address,
    'multiple or erc721 gated follow module': multipleOrERC721GateFollowModule.address,
    'profile and gated follow module': profilesGateAndFollowModule.address,
    'profile or gated follow module': profilesGateOrFollowModule.address,
    'limited rewards reference module': limitedRewardsReferenceModule.address,
    'limited rewards exponential reference module':
      limitedRewardsExponentialReferenceModule.address,
  };
  const json = JSON.stringify(addrs, null, 2);
  console.log(json);

  fs.writeFileSync('addresses.json', json, 'utf-8');
});
