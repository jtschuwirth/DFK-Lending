var BasicERC20 = artifacts.require("BasicERC20");
var BasicERC721 = artifacts.require("BasicERC721");
var ERC721Lending = artifacts.require("ERC721Lending");

module.exports = async function(deployer) {
  await deployer.deploy(BasicERC20)
  await deployer.deploy(BasicERC721)
  await deployer.deploy(ERC721Lending, "0xfd768E668A158C173e9549d1632902C2A4363178", BasicERC20.address)
};