// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract HeroLending is ERC721Holder, ReentrancyGuard {

    event NewOffer(uint offerId);
    event CancelOffer(uint offerId);
    event AcceptOffer(uint offerId);
    event RepayOffer(uint offerId);
    event Liquidate(uint offerId);

    struct Offer {
        address owner;
        uint heroId;
        uint liquidation;
        uint dailyFee;

        address borrower;
        uint collateral;
        uint acceptTime;

        string status;
    }

    address PayOutAddress;
    Offer[] public offers;
    IERC721 hero;
    IERC20 jewel;

    constructor(address JewelAddress, address HeroAddress) {
        PayOutAddress = 0x867df63D1eEAEF93984250f78B4bd83C70652dcE;
        hero = IERC721(HeroAddress);
        jewel = IERC20(JewelAddress);
    }

    //View Functions

    function offerOwner(uint offerId) public view returns (address) {
        return offers[offerId].owner;
    }

    function offerHeroId(uint offerId) public view returns (uint) {
        return offers[offerId].heroId;
    }

    function offerLiquidation(uint offerId) public view returns (uint) {
        return offers[offerId].liquidation;
    }

    function offerDailyFee(uint offerId) public view returns (uint) {
        return offers[offerId].dailyFee;
    }



    function offerBorrower(uint offerId) public view returns (address) {
        return offers[offerId].borrower;
    }

    function offerCollateral(uint offerId) public view returns (uint) {
        return offers[offerId].collateral;
    }

    function offerAcceptTime(uint offerId) public view returns (uint) {
        return offers[offerId].acceptTime;
    }



    function offerStatus(uint offerId) public view returns (string memory) {
        return offers[offerId].status;
    }

    function offersQuantity() public view returns (uint) {
        uint quantity = offers.length;
        return quantity;
    }

    //Main Functions

    function createOffer(uint heroId, uint liquidation, uint fee) public nonReentrant() {
        require(hero.ownerOf(heroId) == msg.sender);

        uint offerId = offers.length;
        offers.push(Offer(msg.sender, heroId, liquidation, fee, address(0), 0, 0, "Open"));
        hero.safeTransferFrom(msg.sender, address(this), heroId);
        emit NewOffer(offerId);
    }

    function cancelOffer(uint offerId) public nonReentrant() {
        require(offers[offerId].owner == msg.sender);
        require(hero.ownerOf(offers[offerId].heroId) == address(this));
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")));

        offers[offerId].status = "Cancelled";
        hero.safeTransferFrom(address(this), msg.sender, offers[offerId].heroId);
        emit CancelOffer(offerId);
    }

    function acceptOffer(uint offerId, uint collateral) public nonReentrant() {
        require(offers[offerId].owner != msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")));
        uint minimumFee = offers[offerId].dailyFee/24;
        require(collateral > offers[offerId].liquidation + minimumFee);
        require(jewel.balanceOf(msg.sender) >= collateral);

        offers[offerId].status = "On";
        offers[offerId].borrower = msg.sender;
        offers[offerId].collateral = collateral;
        offers[offerId].acceptTime = block.timestamp;
        jewel.transferFrom(msg.sender, address(this), collateral);
        hero.safeTransferFrom(address(this), msg.sender, offers[offerId].heroId);
        emit AcceptOffer(offerId);
    }

    function repayOffer(uint offerId) public nonReentrant() {
        require(offers[offerId].borrower == msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")));
        require(hero.ownerOf(offers[offerId].heroId) == msg.sender);
        require(jewel.balanceOf(address(this)) >= offers[offerId].collateral);
        require(offers[offerId].acceptTime != 0);
        uint feeToPay;
        //minimum Fee is at least 1 hour
        if ((block.timestamp - offers[offerId].acceptTime) < 60*60) {
            feeToPay = offers[offerId].dailyFee/24;
        } else {
            feeToPay = ((block.timestamp - offers[offerId].acceptTime)/(60*60*24))*offers[offerId].dailyFee;
        }
        // User is not liquidated
        require(offers[offerId].collateral > (feeToPay + offers[offerId].liquidation));

        jewel.transfer(offers[offerId].owner, feeToPay*96/100);
        jewel.transfer(PayOutAddress, feeToPay*4/100);
        jewel.transfer(msg.sender, (offers[offerId].collateral - feeToPay));
        hero.safeTransferFrom(msg.sender, address(this), offers[offerId].heroId);

        offers[offerId].borrower = address(0);
        offers[offerId].collateral = 0;
        offers[offerId].acceptTime = 0;
        offers[offerId].status = "Open";
        emit RepayOffer(offerId);
    }

    function addCollateral(uint offerId, uint extraCollateral) public nonReentrant() {
        require(offers[offerId].borrower == msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")));
        require(jewel.balanceOf(address(this)) >= extraCollateral);

        offers[offerId].collateral = offers[offerId].collateral + extraCollateral;
        jewel.transferFrom(msg.sender, address(this), extraCollateral);
    }

    function liquidate(uint offerId) public nonReentrant() {
        uint feeToPay = ((block.timestamp - offers[offerId].acceptTime)/(60*60*24))*offers[offerId].dailyFee;
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")));
        require(offers[offerId].collateral < (feeToPay + offers[offerId].liquidation));

        offers[offerId].status = "Liquidated";
        jewel.transfer(offers[offerId].owner, offers[offerId].collateral*90/100);
        jewel.transfer(PayOutAddress, offers[offerId].collateral*10/100);
        emit Liquidate(offerId);
    }
}