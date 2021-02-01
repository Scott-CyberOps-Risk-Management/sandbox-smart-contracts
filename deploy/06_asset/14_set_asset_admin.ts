import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {execute, read} = deployments;

  const {assetAdmin, assetBouncerAdmin} = await getNamedAccounts();

  let currentAdmin;
  try {
    currentAdmin = await read('Asset', 'getAdmin');
  } catch (e) {
    // no admin
  }

  let currentBouncerAdmin;
  try {
    currentBouncerAdmin = await read('Asset', 'getBouncerAdmin');
  } catch (e) {
    // no admin
  }
  console.log('current', currentBouncerAdmin);

  if (currentBouncerAdmin) {
    if (currentBouncerAdmin.toLowerCase() !== assetBouncerAdmin.toLowerCase()) {
      await execute(
        'Asset',
        {from: currentAdmin, log: true},
        'changeBouncerAdmin',
        assetBouncerAdmin
      );
      console.log('asset', assetBouncerAdmin);
    }
  }

  try {
    currentBouncerAdmin = await read('Asset', 'getBouncerAdmin');
  } catch (e) {
    // no admin
  }
  console.log('new', currentBouncerAdmin);

  if (currentAdmin) {
    if (currentAdmin.toLowerCase() !== assetAdmin.toLowerCase()) {
      await execute(
        'Asset',
        {from: currentAdmin, log: true},
        'changeAdmin',
        assetAdmin
      );
    }
  }
};
export default func;
func.runAtTheEnd = true;
func.tags = ['Asset', 'Asset_setup'];
func.dependencies = ['Asset_deploy'];

func.skip = async (hre) => hre.network.name !== 'hardhat'; // TODO reenable once all assets are migrated
