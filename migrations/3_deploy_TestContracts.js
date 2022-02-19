var BasicERC20 = artifacts.require("BasicERC20");
var BasicERC721 = artifacts.require("BasicERC721");
var HeroLending = artifacts.require("HeroLending");

module.exports = async function(deployer) {
  await deployer.deploy(BasicERC20)
  await deployer.deploy(BasicERC721)
  await deployer.deploy(HeroLending, BasicERC20.address, BasicERC721.address)
};