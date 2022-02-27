const { deployProxy } = require('@openzeppelin/truffle-upgrades');

var BasicERC20 = artifacts.require("BasicERC20");
var BasicERC721 = artifacts.require("BasicERC721");
const ERC721LendingUpgradeable = artifacts.require("ERC721LendingUpgradeable");

module.exports = async function (deployer) {
    await deployer.deploy(BasicERC20)
    await deployer.deploy(BasicERC721)
    await deployProxy(ERC721LendingUpgradeable, ["0xfd768E668A158C173e9549d1632902C2A4363178", BasicERC20.address, BasicERC721.address], { deployer, initializer: "initialize" });
};