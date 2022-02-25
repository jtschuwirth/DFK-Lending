// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";



/**
 * @title ERC721Lending
 * @notice ERC721 Lending plataform where users that provide the ERC721 token
 * set a liquidation limit and fee, and users that borrow the ERC721 token
 * set how much collateral they add to the transaction
 */
contract ERC721Lending is ERC721Holder, ReentrancyGuard, AccessControl {

    event OfferStatusChange(uint256 offerId, string status);

    struct Offer {
        address owner;
        address nft;
        uint256 nftId;
        uint256 liquidation;
        uint256 hourlyFee;
        address borrower;
        uint256 collateral;
        uint256 acceptTime;
        string status; // Open, On, Cancelled, Liquidated
    }

    mapping(uint256 => Offer) offers;
    mapping(address => uint256[]) addressToOffers;
    mapping(address => bool) addressToBool;

    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    Counters.Counter private offerCounter;

    address PayoutAddress;
    IERC20 token;
    uint Fee;
    uint LiquidationFee;

    constructor(address Payout, address TokenAddress, address BaseERC721Address) {
        PayoutAddress = Payout;
        token = IERC20(TokenAddress);
        Fee = 4;
        LiquidationFee = 10;
        //Base Contract accepted
        addressToBool[BaseERC721Address] = true;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Returns the details for a offer.
     * @param offerId The id of the offer.
     */
    function getOffer(uint256 offerId) external view returns (address, address, uint256, uint256, uint256, address, uint256, uint256, string memory) {
        Offer memory offer = offers[offerId];
        return (offer.owner, offer.nft, offer.nftId, offer.liquidation, offer.hourlyFee, offer.borrower, offer.collateral, offer.acceptTime, offer.status);
    }

    /**
     * @dev Returns all offers of an address.
     * @param addr the address to lookup.
     */
    function getOffersOfAddress(address addr) external view returns (uint256[] memory) {
        return addressToOffers[addr];
    }

    /**
     * @dev Returns the number of offers made.
     */
    function getOfferQuantities() external view returns (uint256) {
        return offerCounter.current();
    }

    function feeToPay(uint256 offerId) public view returns (uint256) {
        return offers[offerId].hourlyFee + ((block.timestamp - offers[offerId].acceptTime)/(60*60))*offers[offerId].hourlyFee;
    }

    /**
     * @dev Opens a new Offer, and sends the nft to an escrow.
     * @param nftId id of the nft to offer.
     * @param nftAddress address of the nft to offer.
     * @param liquidation if the amount of liquidation+accumulatedFee is bigger than the collateral, the borrower is liquidated.
     * @param fee fee amount that accumulates every hour.
     */
    function createOffer(uint256 nftId, address nftAddress, uint256 liquidation, uint256 fee) external nonReentrant() {
        require(addressToBool[nftAddress] == true);
        require(IERC721(nftAddress).ownerOf(nftId) == msg.sender, "Not the owner of the NFT");
        
        IERC721(nftAddress).safeTransferFrom(msg.sender, address(this), nftId);

        uint current = offerCounter.current();
        offerCounter.increment();
        offers[current] = Offer(msg.sender, nftAddress, nftId, liquidation, fee, address(0), 0, 0, "Open");
        addressToOffers[msg.sender].push(current);
        emit OfferStatusChange(current, "Open");
    }

    /**
     * @dev Cancels open offer and returns the nft to the owner.
     * @param offerId the id of the offer.
     */
    function cancelOffer(uint256 offerId) external nonReentrant() {
        require(offers[offerId].owner == msg.sender, "Not the owner of the Offer");
        require(IERC721(offers[offerId].nft).ownerOf(offers[offerId].nftId) == address(this), "The Protocol does not have the NFT");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")), "Offer is not Open");

        offers[offerId].status = "Cancelled";
        IERC721(offers[offerId].nft).safeTransferFrom(address(this), msg.sender, offers[offerId].nftId);
        emit OfferStatusChange(offerId, "Cancelled");
    }

    /**
     * @dev Accepts an Open offer, escrows the collateral on the contract and sends the nft to the borrower.
     * @param offerId the id of the offer.
     * @param collateral how much collateral the borrowers wants to add to the offer.
     */
    function acceptOffer(uint256 offerId, uint256 collateral) external nonReentrant() {
        require(offers[offerId].owner != msg.sender, "Can not accept your own Offer");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")), "Offer is not Open");
        uint256 minimumFee = offers[offerId].hourlyFee;
        require(collateral > offers[offerId].liquidation + minimumFee, "Not enough collateral to borrow for more than an hour");
        require(token.balanceOf(msg.sender) >= collateral, "Not enough balance to pay the collateral");

        offers[offerId].status = "On";
        offers[offerId].borrower = msg.sender;
        offers[offerId].collateral = collateral;
        offers[offerId].acceptTime = block.timestamp;
        token.safeTransferFrom(msg.sender, address(this), collateral);
        IERC721(offers[offerId].nft).safeTransferFrom(address(this), msg.sender, offers[offerId].nftId);
        emit OfferStatusChange(offerId, "On");
    }

    /**
     * @dev checks if borrower is liquidated or not, then transfers the nft to the contract, 
     * pays the lender, pays the protocol and finally returns the rest of the collateral to the borrower
     * @param offerId the id of the offer.
     */
    function repayOffer(uint256 offerId) external nonReentrant() {
        require(offers[offerId].borrower == msg.sender, "Only borrower can repay the Offer");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")), "Offer is not On");
        require(IERC721(offers[offerId].nft).ownerOf(offers[offerId].nftId) == msg.sender, "Borrower is not owner of the NFT");
        require(token.balanceOf(address(this)) >= offers[offerId].collateral, "Protocol does not have enough to pay the collateral");
        require(offers[offerId].acceptTime != 0, "Accept time = 0");
        //minimum Fee is at least 1 hour and increases each hour
        uint256 fee = feeToPay(offerId);
        // User is not liquidated
        require(offers[offerId].collateral >= (fee + offers[offerId].liquidation), "Borrower can be Liquidated");

        IERC721(offers[offerId].nft).safeTransferFrom(msg.sender, address(this), offers[offerId].nftId);
        token.safeTransfer(offers[offerId].owner, fee*(100-Fee)/100);
        token.safeTransfer(PayoutAddress, fee*Fee/100);
        token.safeTransfer(msg.sender, (offers[offerId].collateral - fee));

        offers[offerId].borrower = address(0);
        offers[offerId].collateral = 0;
        offers[offerId].acceptTime = 0;
        offers[offerId].status = "Open";
        emit OfferStatusChange(offerId, "Open");
    }

    /**
     * @dev Adds extra collateral to the position of the borrower.
     * @param offerId the id of the offer.
     * @param extraCollateral how much extra collateral the borrowers wants to add to the offer.
     */
    function addCollateral(uint256 offerId, uint256 extraCollateral) external nonReentrant() {
        require(offers[offerId].borrower == msg.sender, "Only borrower can add collateral");
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")), "Offer is not On");
        require(token.balanceOf(offers[offerId].borrower) >= extraCollateral, "Borrower does not have enough to pay the extra collateral");

        offers[offerId].collateral = offers[offerId].collateral + extraCollateral;
        token.safeTransferFrom(msg.sender, address(this), extraCollateral);
    }

    /**
     * @dev Liquidates the borrower if he owns more than he has collateral.
     * @param offerId the id of the offer.
     */
    function liquidate(uint256 offerId) external nonReentrant() {
        uint256 fee = feeToPay(offerId);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")), "Offer is not On");
        require(offers[offerId].collateral < (fee + offers[offerId].liquidation), "Borrower is not Liquidated");

        offers[offerId].status = "Liquidated";
        token.safeTransfer(offers[offerId].owner, offers[offerId].collateral*(100-LiquidationFee)/100);
        token.safeTransfer(PayoutAddress, offers[offerId].collateral*LiquidationFee/100);
        emit OfferStatusChange(offerId, "Liquidated");
    }

    /**
     * @dev Changes account to send payout.
     * @param newPayout new address to send payout.
     */
    function transferPayoutAddress(address newPayout) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PayoutAddress = newPayout;
    }

    /**
     * @dev Changes the fee 
     * @param newFee new fee.
     */
    function changeFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Fee = newFee;
    }

    /**
     * @dev Changes the liquidation fee
     * @param newLiquidationFee new liquidation fee.
     */
    function changeLiquidationFee(uint256 newLiquidationFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        LiquidationFee = newLiquidationFee;
    }

    /**
     * @dev adds new contract ERC721 to the protocol
     * @param _contract contract address to whitelist.
     */
    function addContract(address _contract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        addressToBool[_contract] = true;
    }

    /**
     * @dev removes a contract ERC721 from the protocol
     * @param _contract contract address to blacklist.
     */
    function removeContract(address _contract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        addressToBool[_contract] = false;
    }

}