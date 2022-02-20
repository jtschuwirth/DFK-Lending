const BasicERC20 = artifacts.require("BasicERC20");
const BasicERC721 = artifacts.require("BasicERC721");
const ERC721Lending = artifacts.require("ERC721Lending");

contract("Testing", (accounts) => {
    let alice = accounts[0];
    let bob = accounts[1];
    let BasicERC20Contract;
    let BasicERC721Contract;
    let ERC721LendingContract;


    before(async () => {
        BasicERC20Contract = await BasicERC20.deployed();
        BasicERC721Contract = await BasicERC721.deployed();
        ERC721LendingContract = await ERC721Lending.deployed();
    });

    it("Should be able to mint 100 ERC20 Tokens to account[0] and account[1]", async () => {
        const mint1 = await BasicERC20Contract.mint(alice, 100, {from: alice});
        const mint2 = await BasicERC20Contract.mint(bob, 100, {from: bob});
        const initialBalance = await BasicERC20Contract.balanceOf(bob, {from: bob})
        assert.equal(mint1.receipt.status, true);
        assert.equal(mint2.receipt.status, true);
    })

    it("Should be able to mint one ERC721 NFT to account[0] and owner be account[0]", async () => {
        const result = await BasicERC721Contract.mint(alice, {from: alice});
        const owner = await BasicERC721Contract.ownerOf(0, {from:alice});
        assert.equal(result.receipt.status, true);
        assert.equal(owner, alice);
    })
    
    it("account[0] can create an offer for his NFT with id=0", async () => {
        const approve = await BasicERC721Contract.approve(ERC721LendingContract.address, 0, {from: alice});
        assert.equal(approve.receipt.status, true);
        const lend = await ERC721LendingContract.createOffer(0, BasicERC721Contract.address, 50, 24, {from: alice});
        const owner = await BasicERC721Contract.ownerOf(0, {from: alice});
        const offerData = await ERC721LendingContract.getOffer(1, {from: alice});
       
        assert.equal(lend.receipt.status, true);
        assert.equal(owner, ERC721LendingContract.address);
        assert.equal(offerData[8], "Open")
    });


    it("account[1] can borrow the offer with id=1 with 60 collateral", async () => {
        const approve = await BasicERC20Contract.approve(ERC721LendingContract.address, 10000000, {from:bob});
        assert.equal(approve.receipt.status, true);
        const borrow = await ERC721LendingContract.acceptOffer(1, 60, {from: bob});
        const owner = await BasicERC721Contract.ownerOf(0, {from: bob});
        const offerData = await ERC721LendingContract.getOffer(1, {from: bob});
        const finalBalance = await BasicERC20Contract.balanceOf(bob, {from: bob})
        
        assert.equal(borrow.receipt.status, true);
        assert.equal(owner, bob);
        assert.equal(offerData[8], "On")
    });

    it("account[1] can repay the borrowed ERC721", async () => {
        const approve = await BasicERC721Contract.approve(ERC721LendingContract.address, 0, {from:bob});
        assert.equal(approve.receipt.status, true);
        const repay = await ERC721LendingContract.repayOffer(1, {from: bob});
        const owner = await BasicERC721Contract.ownerOf(0, {from: bob});
        const offerData = await ERC721LendingContract.getOffer(1, {from: bob});
        const finalBalance = await BasicERC20Contract.balanceOf(bob, {from: bob})
        
        assert.equal(owner, ERC721LendingContract.address);
        assert.equal(repay.receipt.status, true);
        assert.equal(offerData[8], "Open")
    });

});