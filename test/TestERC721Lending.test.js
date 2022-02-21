const {
    BN,           // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
    increase,
    time, 
  } = require('@openzeppelin/test-helpers');


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
        const initialBalance = await BasicERC20Contract.balanceOf(bob, {from: bob});
        assert.equal(mint1.receipt.status, true);
        assert.equal(mint2.receipt.status, true);
    })

    it("Should be able to mint two ERC721 NFT to account[0] and owner be account[0]", async () => {
        const mint1 = await BasicERC721Contract.mint(alice, {from: alice});
        const mint2 = await BasicERC721Contract.mint(alice, {from: alice});
        const owner = await BasicERC721Contract.ownerOf(0, {from:alice});
        assert.equal(mint1.receipt.status, true);
        assert.equal(mint2.receipt.status, true);
        assert.equal(owner, alice);
    })
    
    it("account[0] can create an offer for his NFT with id=0", async () => {
        let liquidation = 50;
        let hourlyFee = 1;
        let nftId = 0;

        const approve = await BasicERC721Contract.approve(ERC721LendingContract.address, nftId, {from: alice});
        assert.equal(approve.receipt.status, true);
        const lend = await ERC721LendingContract.createOffer(nftId, BasicERC721Contract.address, liquidation, hourlyFee, {from: alice});
        const owner = await BasicERC721Contract.ownerOf(nftId, {from: alice});
        const offerData = await ERC721LendingContract.getOffer(1, {from: alice});
       
        assert.equal(lend.receipt.status, true);
        assert.equal(owner, ERC721LendingContract.address);
        assert.equal(offerData[8], "Open");
    });


    it("account[1] can borrow the offer with id=1 with 60 collateral", async () => {
        let collateral = 60;
        let offerId = 1;
        let nftId = 0;

        const approve = await BasicERC20Contract.approve(ERC721LendingContract.address, 10000000, {from:bob});
        assert.equal(approve.receipt.status, true);
        const borrow = await ERC721LendingContract.acceptOffer(offerId, collateral, {from: bob});
        const owner = await BasicERC721Contract.ownerOf(nftId, {from: bob});
        const offerData = await ERC721LendingContract.getOffer(offerId, {from: bob});
        const finalBalance = await BasicERC20Contract.balanceOf(bob, {from: bob});
         
        //expectEvent(borrow, 'Transfer', { from: bob, to: ERC721LendingContract.address, amount: collateral});
        assert.equal(borrow.receipt.status, true);
        assert.equal(owner, bob);
        assert.equal(offerData[8], "On");
    });

    it("account[1] can repay the offer with id=1", async () => {
        const approve = await BasicERC721Contract.approve(ERC721LendingContract.address, 0, {from:bob});
        assert.equal(approve.receipt.status, true);
        const repay = await ERC721LendingContract.repayOffer(1, {from: bob});
        const owner = await BasicERC721Contract.ownerOf(0, {from: bob});
        const offerData = await ERC721LendingContract.getOffer(1, {from: bob});
        const finalBalance = await BasicERC20Contract.balanceOf(bob, {from: bob});
        
        //expectEvent(repay, 'Transfer', { from: ERC721LendingContract.address, to: alice});
        assert.equal(owner, ERC721LendingContract.address);
        assert.equal(repay.receipt.status, true);
        assert.equal(offerData[8], "Open");
    });

    it("account[0] can create an offer for his NFT with id=1", async () => {
        const approve = await BasicERC721Contract.approve(ERC721LendingContract.address, 1, {from: alice});
        assert.equal(approve.receipt.status, true);
        const lend = await ERC721LendingContract.createOffer(1, BasicERC721Contract.address, 50, 1, {from: alice});
        const owner = await BasicERC721Contract.ownerOf(1, {from: alice});
        const offerData = await ERC721LendingContract.getOffer(2, {from: alice});
       
        assert.equal(lend.receipt.status, true);
        assert.equal(owner, ERC721LendingContract.address);
        assert.equal(offerData[8], "Open");
    });

    it("account[1] can borrow the offer with id=2 with 60 collateral", async () => {
        const approve = await BasicERC20Contract.approve(ERC721LendingContract.address, 10000000, {from:bob});
        assert.equal(approve.receipt.status, true);
        const borrow = await ERC721LendingContract.acceptOffer(2, 74, {from: bob});
        const owner = await BasicERC721Contract.ownerOf(1, {from: bob});
        const offerData = await ERC721LendingContract.getOffer(2, {from: bob});
        const finalBalance = await BasicERC20Contract.balanceOf(bob, {from: bob});
        
        assert.equal(borrow.receipt.status, true);
        assert.equal(owner, bob);
        assert.equal(offerData[8], "On");
    });

    it("after an increase of 25 Hours the offer with id=2 con be liquidated", async () => {
        await time.increase(60*60*25);
        const liquidate = await ERC721LendingContract.liquidate(2, {from: alice});
        const owner = await BasicERC721Contract.ownerOf(1, {from: alice});
        const offerData = await ERC721LendingContract.getOffer(2, {from: bob});

        //expectEvent(liquidate, 'Transfer', { from: ERC721LendingContract.address, to: alice});
        assert.equal(liquidate.receipt.status, true);
        assert.equal(owner, bob);
        assert.equal(offerData[8], "Liquidated");
    });


});