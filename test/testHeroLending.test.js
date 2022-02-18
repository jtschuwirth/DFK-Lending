const HeroLending = artifacts.require("HeroLending");
const BasicERC20 = artifacts.require("BasicERC20");
const BasicERC721 = artifacts.require("BasicERC721");

contract("HeroLending", (accounts) => {
    let alice = accounts[0];
    let bob = accounts[1];
    let HeroLendingContract;
    let BasicERC20Contract;
    let BasicERC721Contract;


    before(async () => {
        HeroLendingContract = await HeroLending.deployed();
        BasicERC20Contract = await BasicERC20.deployed();
        BasicERC721Contract = await BasicERC721.deployed();
    });

    it("Should be able to mint 100 ERC20 Tokens to alice and bob", async () => {
        const result1 = await BasicERC20.mint(100, {from: alice});
        const result2 = await BasicERC20.mint(100, {from: bob});
        assert.equal(result1.receipt.status, true);
        assert.equal(result2.receipt.status, true);
    })

    it("Should be able to mint one ERC721 NFT to account[0]", async () => {
        const result = await BasicERC721.mint(alice, {from: alice});
        assert.equal(result.receipt.status, true);
    })
});