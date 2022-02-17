const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const HeroLending = artifacts.require("HeroLending");

module.exports = async function (deployer) {
  await deployProxy(HeroLending, { deployer, initializer: "initialize" });
};