const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const HeroLendingUpgradeable = artifacts.require("HeroLendingUpgradeable");

module.exports = async function (deployer) {
  await deployProxy(HeroLendingUpgradeable, { deployer, initializer: "initialize" });
};