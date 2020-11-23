/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/explicit-module-boundary-types */
import {utils} from 'ethers';
const {solidityKeccak256} = utils;
import crypto from 'crypto';

function calculateLandHash(land: any, salt?: any) {
  const types = [
    'uint256',
    'uint256',
    'uint256',
    'uint256',
    'address',
    'bytes32',
  ];
  const values = [
    land.x,
    land.y,
    land.size,
    land.price,
    land.reserved || '0x0000000000000000000000000000000000000000',
    land.salt || salt,
  ];
  if (land.assetIds) {
    types.push('uint256[]');
    values.push(land.assetIds);
  }
  return solidityKeccak256(types, values);
}

function saltLands(lands: any, secret?: any) {
  const saltedLands = [];
  for (const land of lands) {
    let salt = land.salt;
    if (!salt) {
      if (!secret) {
        throw new Error('Land need to have a salt or be generated via secret');
      }
      salt =
        '0x' +
        crypto
          .createHmac('sha256', secret)
          .update(
            calculateLandHash(
              land,
              '0x0000000000000000000000000000000000000000000000000000000000000000'
            )
          )
          .digest('hex');
    }
    saltedLands.push({
      x: land.x,
      y: land.y,
      size: land.size,
      price: land.price,
      reserved: land.reserved,
      salt,
      assetIds: land.assetIds,
    });
  }
  return saltedLands;
}

function createDataArray(lands: any, secret?: any) {
  const data: any = [];

  lands.forEach((land: any) => {
    let salt = land.salt;
    if (!salt) {
      if (!secret) {
        throw new Error('Land need to have a salt or be generated via secret');
      }
      salt =
        '0x' +
        crypto
          .createHmac('sha256', secret)
          .update(
            calculateLandHash(
              land,
              '0x0000000000000000000000000000000000000000000000000000000000000000'
            )
          )
          .digest('hex');
    }
    data.push(calculateLandHash(land, salt));
  });

  return data;
}

function calculateAssetHash(asset: any, salt?: any) {
  const types = ['address', 'uint256[]', 'uint256[]', 'bytes32'];
  const values = [
    asset.reservedAddress,
    asset.assetIds,
    asset.assetValues,
    asset.salt || salt,
  ];
  return solidityKeccak256(types, values);
}

function saltAssets(assets: any, secret?: any) {
  const saltedAssets = [];
  for (const asset of assets) {
    let salt = asset.salt;
    if (!salt || salt === undefined) {
      if (!secret) {
        throw new Error('Asset need to have a salt or be generated via secret');
      }
      salt =
        '0x' +
        crypto
          .createHmac('sha256', secret)
          .update(
            calculateAssetHash(
              asset,
              '0x0000000000000000000000000000000000000000000000000000000000000000'
            )
          )
          .digest('hex');
    }
    saltedAssets.push({
      reservedAddress: asset.reservedAddress,
      assetIds: asset.assetIds,
      assetValues: asset.assetValues,
      salt,
    });
  }
  return saltedAssets;
}

function createDataArrayAssets(assets: any, secret?: any) {
  const data: any = [];

  interface asset {
    reservedAddress: string;
    assetIds: Array<string>;
    assetValues: Array<string>;
    salt?: string;
  }

  assets.forEach((asset: asset) => {
    let salt = asset.salt;
    if (!salt || salt === undefined) {
      if (!secret) {
        throw new Error('Asset need to have a salt or be generated via secret');
      }
      salt =
        '0x' +
        crypto
          .createHmac('sha256', secret)
          .update(
            calculateAssetHash(
              asset,
              '0x0000000000000000000000000000000000000000000000000000000000000000'
            )
          )
          .digest('hex');
    }
    data.push(calculateAssetHash(asset, salt));
  });

  return data;
}

const helpers = {
  createDataArray,
  calculateLandHash,
  saltLands,
  calculateAssetHash,
  saltAssets,
  createDataArrayAssets,
};

export default helpers;