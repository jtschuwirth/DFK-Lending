// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";

contract ERC721Lending is ERC721Holder, ReentrancyGuard, AccessControl {

    event OfferStatusChange(uint offerId, string status);

    struct Offer {
        address owner;
        address nft;
        uint nftId;
        uint liquidation;
        uint dailyFee;

        address borrower;
        uint collateral;
        uint acceptTime;

        string status; // Open, On, Cancelled, Liquidated
    }

    mapping(uint256 => Offer) offers;
    mapping(address => uint256[]) addressToOffers;

    using Counters for Counters.Counter;
    Counters.Counter private offerCounter;

    address PayoutAddress;
    IERC20 token;

    constructor(address Payout, address TokenAddress) {
        PayoutAddress = Payout;
        token = IERC20(TokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getOffer(uint offerId) external view returns (address, address, uint, uint, uint, address, uint, uint, string memory) {
        Offer memory offer = offers[offerId];
        return (offer.owner, offer.nft, offer.nftId, offer.liquidation, offer.dailyFee, offer.borrower, offer.collateral, offer.acceptTime, offer.status);
    }

    function getOffersOfAddress(address addr) external view returns (uint[] memory) {
        return addressToOffers[addr];
    }

    function getOfferQuantities() external view returns (uint) {
        return offerCounter.current();
    }


    //Main Functions

    function createOffer(uint nftId, address nftAddress, uint liquidation, uint fee) external nonReentrant() {
        //TODO: Check if NFTAddress belongs to ERC721 compliant token
        require(IERC721(nftAddress).ownerOf(nftId) == msg.sender, "Not the owner of the NFT");
        IERC721(nftAddress).safeTransferFrom(msg.sender, address(this), nftId);

        offerCounter.increment();
        offers[offerCounter.current()] = Offer(msg.sender, nftAddress, nftId, liquidation, fee, address(0), 0, 0, "Open");
        addressToOffers[msg.sender].push(offerCounter.current());
        emit OfferStatusChange(offerCounter.current(), "Open");
    }

    function cancelOffer(uint offerId) external nonReentrant() {
        require(offers[offerId].owner == msg.sender, "Not the owner of the Offer");
        require(IERC721(offers[offerId].nft).ownerOf(offers[offerId].nftId) == address(this), "The Protocol does not have the NFT");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")), "Offer is not Open");

        offers[offerId].status = "Cancelled";
        IERC721(offers[offerId].nft).safeTransferFrom(address(this), msg.sender, offers[offerId].nftId);
        emit OfferStatusChange(offerId, "Cancelled");
    }

    function acceptOffer(uint offerId, uint collateral) external nonReentrant() {
        require(offers[offerId].owner != msg.sender, "Can not accept your own Offer");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")), "Offer is not Open");
        uint minimumFee = offers[offerId].dailyFee/24;
        require(collateral > offers[offerId].liquidation + minimumFee, "Not enough collateral to borrow for more than an hour");
        require(token.balanceOf(msg.sender) >= collateral, "Not enough balance to pay the collateral");

        offers[offerId].status = "On";
        offers[offerId].borrower = msg.sender;
        offers[offerId].collateral = collateral;
        offers[offerId].acceptTime = block.timestamp;
        token.transferFrom(msg.sender, address(this), collateral);
        IERC721(offers[offerId].nft).safeTransferFrom(address(this), msg.sender, offers[offerId].nftId);
        emit OfferStatusChange(offerId, "On");
    }

    function repayOffer(uint offerId) external nonReentrant() {
        require(offers[offerId].borrower == msg.sender, "Only borrower can repay the Offer");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")), "Offer is not On");
        require(IERC721(offers[offerId].nft).ownerOf(offers[offerId].nftId) == msg.sender, "Borrower is not owner of the NFT");
        require(token.balanceOf(address(this)) >= offers[offerId].collateral, "Protocol does not have enough to pay the collateral");
        require(offers[offerId].acceptTime != 0, "Accept time = 0");
        uint feeToPay;
        //minimum Fee is at least 1 hour
        if ((block.timestamp - offers[offerId].acceptTime) < 60*60) {
            feeToPay = offers[offerId].dailyFee/24;
        } else {
            feeToPay = ((block.timestamp - offers[offerId].acceptTime)/(60*60*24))*offers[offerId].dailyFee;
        }
        // User is not liquidated
        require(offers[offerId].collateral > (feeToPay + offers[offerId].liquidation), "Borrower can be Liquidated");

        token.transfer(offers[offerId].owner, feeToPay*96/100);
        token.transfer(PayoutAddress, feeToPay*4/100);
        token.transfer(msg.sender, (offers[offerId].collateral - feeToPay));
        IERC721(offers[offerId].nft).safeTransferFrom(msg.sender, address(this), offers[offerId].nftId);

        offers[offerId].borrower = address(0);
        offers[offerId].collateral = 0;
        offers[offerId].acceptTime = 0;
        offers[offerId].status = "Open";
        emit OfferStatusChange(offerId, "Open");
    }

    function addCollateral(uint offerId, uint extraCollateral) external nonReentrant() {
        require(offers[offerId].borrower == msg.sender, "Only borrower can add collateral");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")), "Offer is not On");
        require(token.balanceOf(offers[offerId].borrower) >= extraCollateral, "Borrower does not have enough to pay the extra collateral");

        offers[offerId].collateral = offers[offerId].collateral + extraCollateral;
        token.transferFrom(msg.sender, address(this), extraCollateral);
    }

    function liquidate(uint offerId) external nonReentrant() {
        uint feeToPay = ((block.timestamp - offers[offerId].acceptTime)/(60*60*24))*offers[offerId].dailyFee;
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")), "Offer is not On");
        require(offers[offerId].collateral < (feeToPay + offers[offerId].liquidation), "Borrower is not Liquidated");

        offers[offerId].status = "Liquidated";
        token.transfer(offers[offerId].owner, offers[offerId].collateral*90/100);
        token.transfer(PayoutAddress, offers[offerId].collateral*10/100);
        emit OfferStatusChange(offerId, "Liquidated");
    }

    function transferPayoutAddress(address newPayout) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PayoutAddress = newPayout;
    }
}