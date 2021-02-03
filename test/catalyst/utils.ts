import {BigNumber, Contract, Event} from 'ethers';
import {ethers, getNamedAccounts} from 'hardhat';
import {Receipt} from 'hardhat-deploy/types';
import {waitFor} from '../../scripts/utils/utils';
import {findEvents} from '../utils';

export async function mintAsset(minter: string, supply: number) {
  const {assetBouncerAdmin} = await getNamedAccounts();
  const assetContract = await ethers.getContract('Asset');

  await waitFor(
    assetContract
      .connect(ethers.provider.getSigner(assetBouncerAdmin))
      .setBouncer(assetBouncerAdmin, true)
  );

  const assetId = await assetContract
    .connect(ethers.provider.getSigner(assetBouncerAdmin))
    .callStatic.mint(
      minter,
      22,
      '0x1111111111111111111111111111111111111111111111111111111111111111',
      1,
      1,
      minter,
      Buffer.from('data')
    );

  await waitFor(
    assetContract
      .connect(ethers.provider.getSigner(assetBouncerAdmin))
      .mint(
        minter,
        22,
        '0x1111111111111111111111111111111111111111111111111111111111111111',
        supply,
        0,
        minter,
        Buffer.from('data')
      )
  );
  return assetId;
}
export async function changeCatalyst(
  assetUpgraderContract: Contract,
  from: string,
  assetId: string,
  catalystId: string,
  gemsIds: string[],
  to: string
) {
  await waitFor(
    assetUpgraderContract
      .connect(ethers.provider.getSigner(from))
      .changeCatalyst(from, assetId, catalystId, gemsIds, to)
  );
}
export async function transferSand(
  sandContract: Contract,
  to: string,
  amount: BigNumber
) {
  const {sandBeneficiary} = await getNamedAccounts();
  await waitFor(
    sandContract
      .connect(ethers.provider.getSigner(sandBeneficiary))
      .transfer(to, amount)
  );
}
export async function mintCatalyst(
  catalystContract: Contract,
  mintingAmount: BigNumber,
  beneficiary: string
) {
  const {catalystMinter} = await getNamedAccounts();

  await waitFor(
    catalystContract
      .connect(ethers.provider.getSigner(catalystMinter))
      .mint(beneficiary, mintingAmount)
  );
}
export async function mintGem(
  gemContract: Contract,
  mintingAmount: BigNumber,
  beneficiary: string
) {
  const {gemMinter} = await getNamedAccounts();

  await waitFor(
    gemContract
      .connect(ethers.provider.getSigner(gemMinter))
      .mint(beneficiary, mintingAmount)
  );
}

class GemEvent {
  gemIds: number[];
  blockHash: string;
  constructor(ids: number[], hash: string) {
    this.gemIds = ids;
    this.blockHash = hash;
  }
}

async function getGemEvent(ids: number[], hash: string): Promise<GemEvent> {
  return new GemEvent(ids, hash);
}

async function findFilteredGemEvents(
  blockHash: string,
  id: BigNumber,
  registry: Contract
): Promise<Event[]> {
  const filter = registry.filters.GemsAdded(id);
  const events = await registry.queryFilter(filter, blockHash);
  return events;
}

interface AttributesObj {
  assetId: BigNumber;
  gemEvents: GemEvent[];
}

export async function prepareGemEventData(
  registry: Contract,
  mintReceipt: Receipt,
  upgradeReceipts: Receipt[]
): Promise<AttributesObj> {
  const catalystAppliedEvents = await findEvents(
    registry,
    'CatalystApplied',
    mintReceipt.blockHash
  );
  let assetId;
  let initialGemEvent: GemEvent;
  const gemEvents: GemEvent[] = [];

  if (catalystAppliedEvents[0].args) {
    assetId = catalystAppliedEvents[0].args[0];
    initialGemEvent = await getGemEvent(
      catalystAppliedEvents[0].args[2],
      mintReceipt.blockHash
    );
    gemEvents.push(initialGemEvent);
  }

  if (upgradeReceipts.length != 0) {
    for (const rec of upgradeReceipts) {
      const gemsAddedEvents = await findFilteredGemEvents(
        rec.blockHash,
        assetId,
        registry
      );
      console.log(`gemsAddedEvents.length: ${gemsAddedEvents.length}`);
      for (const event of gemsAddedEvents) {
        if (event.args) {
          const gemEvent = await getGemEvent(event.args[1], rec.blockHash);
          gemEvents.push(gemEvent);
        }
      }
    }
  }
  return {assetId, gemEvents};
}
