// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract ERC721Lending is ERC721Holder, ReentrancyGuard {

    event NewOffer(uint offerId);
    event CancelOffer(uint offerId);
    event AcceptOffer(uint offerId);
    event RepayOffer(uint offerId);
    event Liquidate(uint offerId);

    struct Offer {
        address owner;
        address nft;
        uint nftId;
        uint liquidation;
        uint dailyFee;

        address borrower;
        uint collateral;
        uint acceptTime;

        string status;
    }

    address PayOutAddress;
    Offer[] public offers;
    IERC20 token;

    constructor(address PayOut, address TokenAddress) {
        PayOutAddress = PayOut;
        token = IERC20(TokenAddress);
    }

    //View Functions

    function offerOwner(uint offerId) public view returns (address) {
        return offers[offerId].owner;
    }

    function offerNFT(uint offerId) public view returns (address) {
        return offers[offerId].nft;
    }

    function offerNFTId(uint offerId) public view returns (uint) {
        return offers[offerId].nftId;
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

    function createOffer(uint nftId, address NFTAddress, uint liquidation, uint fee) public nonReentrant() {
        require(IERC721(NFTAddress).ownerOf(nftId) == msg.sender);

        uint offerId = offers.length;
        offers.push(Offer(msg.sender, NFTAddress, nftId, liquidation, fee, address(0), 0, 0, "Open"));
        IERC721(NFTAddress).safeTransferFrom(msg.sender, address(this), nftId);
        emit NewOffer(offerId);
    }

    function cancelOffer(uint offerId) public nonReentrant() {
        require(offers[offerId].owner == msg.sender);
        require(IERC721(offers[offerId].nft).ownerOf(offers[offerId].nftId) == address(this));
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")));

        offers[offerId].status = "Cancelled";
        IERC721(offers[offerId].nft).safeTransferFrom(address(this), msg.sender, offers[offerId].nftId);
        emit CancelOffer(offerId);
    }

    function acceptOffer(uint offerId, uint collateral) public nonReentrant() {
        require(offers[offerId].owner != msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")));
        uint minimumFee = offers[offerId].dailyFee/24;
        require(collateral > offers[offerId].liquidation + minimumFee);
        require(token.balanceOf(msg.sender) >= collateral);

        offers[offerId].status = "On";
        offers[offerId].borrower = msg.sender;
        offers[offerId].collateral = collateral;
        offers[offerId].acceptTime = block.timestamp;
        token.transferFrom(msg.sender, address(this), collateral);
        IERC721(offers[offerId].nft).safeTransferFrom(address(this), msg.sender, offers[offerId].nftId);
        emit AcceptOffer(offerId);
    }

    function repayOffer(uint offerId) public nonReentrant() {
        require(offers[offerId].borrower == msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")));
        require(IERC721(offers[offerId].nft).ownerOf(offers[offerId].nftId) == msg.sender);
        require(token.balanceOf(address(this)) >= offers[offerId].collateral);
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

        token.transfer(offers[offerId].owner, feeToPay*96/100);
        token.transfer(PayOutAddress, feeToPay*4/100);
        token.transfer(msg.sender, (offers[offerId].collateral - feeToPay));
        IERC721(offers[offerId].nft).safeTransferFrom(msg.sender, address(this), offers[offerId].nftId);

        offers[offerId].borrower = address(0);
        offers[offerId].collateral = 0;
        offers[offerId].acceptTime = 0;
        offers[offerId].status = "Open";
        emit RepayOffer(offerId);
    }

    function addCollateral(uint offerId, uint extraCollateral) public nonReentrant() {
        require(offers[offerId].borrower == msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")));
        require(token.balanceOf(address(this)) >= extraCollateral);

        offers[offerId].collateral = offers[offerId].collateral + extraCollateral;
        token.transferFrom(msg.sender, address(this), extraCollateral);
    }

    function liquidate(uint offerId) public nonReentrant() {
        uint feeToPay = ((block.timestamp - offers[offerId].acceptTime)/(60*60*24))*offers[offerId].dailyFee;
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")));
        require(offers[offerId].collateral < (feeToPay + offers[offerId].liquidation));

        offers[offerId].status = "Liquidated";
        token.transfer(offers[offerId].owner, offers[offerId].collateral*90/100);
        token.transfer(PayOutAddress, offers[offerId].collateral*10/100);
        emit Liquidate(offerId);
    }
}