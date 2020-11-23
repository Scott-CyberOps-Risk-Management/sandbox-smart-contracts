import fs from 'fs';
import {BigNumber} from 'ethers';
import MerkleTree from '../../lib/merkleTree';
import helpers from '../../lib/merkleTreeHelper';
import * as assetData from './assets.json';

const {createDataArrayAssets, saltAssets} = helpers;

let errors = false;
function reportError(e: string) {
  errors = true;
  console.error(e);
}

function exitIfError() {
  if (errors) {
    process.exit(1);
  }
}

type Assets = {
  assets: Claim[];
};

type Claim = {
  reservedAddress: string;
  assetIds: Array<number>;
  assetValues: Array<number>;
};

function generateAssetsForMerkleTree(assetData: Assets) {
  const assets = [];
  let numClaims = 0;
  let numAssets = 0;

  for (const claim of assetData.assets) {
    const reservedAddress = claim.reservedAddress;
    const assetIds = claim.assetIds;
    const assetValues = claim.assetValues;
    assets.push({
      reservedAddress,
      assetIds,
      assetValues,
    });
    let i;
    for (i = 0; i < claim.assetIds.length; i++) {
      numAssets += claim.assetValues[i];
    }
    numClaims++;
  }

  exitIfError();
  return {assets};
}

function getAssets(isDeploymentChainId: any, chainId: any) {
  if (typeof chainId !== 'string') {
    throw new Error('chainId not a string');
  }

  let secretPath = './.asset_giveaway_1_secret';
  if (BigNumber.from(chainId).toString() === '1') {
    console.log('MAINNET secret');
    secretPath = './.asset_giveaway_1_secret.mainnet';
  }

  let expose = false;
  let secret;
  try {
    secret = fs.readFileSync(secretPath);
  } catch (e) {
    if (isDeploymentChainId) {
      throw e;
    }
    secret =
      '0x4467363716526536535425451427798982881775318563547751090997863683';
  }

  if (!isDeploymentChainId) {
    expose = true;
  }

  const {assets} = generateAssetsForMerkleTree(assetData);

  const saltedAssets = saltAssets(assets, secret);
  const tree = new MerkleTree(createDataArrayAssets(saltedAssets));
  const merkleRootHash = tree.getRoot().hash;

  return {
    assets: expose ? saltedAssets : assets,
    merkleRootHash,
    saltedAssets,
    tree,
  };
}

export default getAssets;