var ERC721Lending = artifacts.require("ERC721Lending");


module.exports = async function(deployer) {
  await deployer.deploy(ERC721Lending, "0x867df63D1eEAEF93984250f78B4bd83C70652dcE", "0xAc8578b232f08b6FeC672adCe63987f5c57c0249", "0xCF88D09658dD442E6FA1d721C2d783a8199B8c06")
};