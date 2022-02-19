const BasicERC20 = artifacts.require("BasicERC20");
const BasicERC721 = artifacts.require("BasicERC721");
const HeroLending = artifacts.require("HeroLending");

contract("Testing", (accounts) => {
    let alice = accounts[0];
    let bob = accounts[1];
    let BasicERC20Contract;
    let BasicERC721Contract;
    let HeroLendingContract;


    before(async () => {
        BasicERC20Contract = await BasicERC20.deployed();
        BasicERC721Contract = await BasicERC721.deployed();
        HeroLendingContract = await HeroLending.deployed();
    });

    it("Should be able to mint 100 ERC20 Tokens to account[0] and account[1]", async () => {
        const mint1 = await BasicERC20Contract.mint(alice, 100, {from: alice});
        const mint2 = await BasicERC20Contract.mint(bob, 100, {from: bob});
        assert.equal(mint1.receipt.status, true);
        assert.equal(mint2.receipt.status, true);
    })

    it("Should be able to mint one ERC721 NFT to account[0] and owner be account[0]", async () => {
        const result = await BasicERC721Contract.mint(alice, {from: alice});
        assert.equal(result.receipt.status, true);
        const owner = await BasicERC721Contract.ownerOf(0, {from:alice});
        assert.equal(owner, alice);
    })
    
    it("account[0] can create an offer for his NFT with id=0", async () => {
        const approve = await BasicERC721Contract.approve(HeroLendingContract.address, 0);
        assert.equal(approve.receipt.status, true);
        const offer = await HeroLendingContract.createOffer(0, 50, 1);
        assert.equal(offer.receipt.status, true);
    });

});