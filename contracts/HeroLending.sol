// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

import "./AbstractHero.sol";
import "./AbstractJewel.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../node_modules/@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract HeroLending is Initializable, AccessControlUpgradeable, ERC721Holder {

    event NewOffer(uint offerId);
    event CancelOffer(uint offerId);

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

    address HeroAddress = address(0);
    address JewelAddress = address(0);
    Offer[] public offers;
    AbstractHero hero;
    AbstractJewel jewel;

    function initialize() initializer public {
        hero = AbstractHero(HeroAddress);
        jewel = AbstractJewel(JewelAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createOffer(uint heroId, uint liquidation, uint fee) public {
        require(hero.ownerOf(heroId) == msg.sender);
        hero.safeTransferFrom(msg.sender, address(this), heroId);
        uint offerId = offers.length;
        offers.push(Offer(msg.sender, heroId, liquidation, fee, address(0), 0, 0, "Open"));
        emit NewOffer(offerId);
    }

    function cancelOffer(uint offerId) public {
        require(offers[offerId].owner == msg.sender);
        require(hero.ownerOf(offers[offerId].heroId) == address(this));
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")));
        offers[offerId].status = "Cancelled";
        hero.safeTransferFrom(address(this), msg.sender, offers[offerId].heroId);
        emit CancelOffer(offerId);
    }

    function acceptOffer(uint offerId, uint collateral) public {
        require(offers[offerId].owner != msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("Open")));
        require(jewel.balanceOf(msg.sender) >= collateral);

        offers[offerId].status = "On";
        offers[offerId].borrower = msg.sender;
        offers[offerId].collateral = collateral;
        offers[offerId].acceptTime = block.timestamp;
        jewel.transferFrom(msg.sender, address(this), collateral);
        hero.safeTransferFrom(address(this), msg.sender, offers[offerId].heroId);
    }

    function repayOffer(uint offerId) public {
        require(offers[offerId].borrower == msg.sender);
        require(keccak256(abi.encodePacked(offers[offerId].status)) == keccak256(abi.encodePacked("On")));
        require(hero.ownerOf(offers[offerId].heroId) == msg.sender);
        require(jewel.balanceOf(address(this)) >= offers[offerId].collateral);
        require(offers[offerId].acceptTime != 0);
        uint feeToPay = ((block.timestamp - offers[offerId].acceptTime)/(60*24))*offers[offerId].dailyFee;
        // User is not liquidated
        require(offers[offerId].collateral > feeToPay+offers[offerId].liquidation);

        jewel.transferFrom(address(this), offers[offerId].owner, feeToPay);
        jewel.transferFrom(address(this), msg.sender, offers[offerId].collateral - feeToPay);
        hero.safeTransferFrom(msg.sender, address(this), offers[offerId].heroId);

        offers[offerId].borrower = address(0);
        offers[offerId].collateral = 0;
        offers[offerId].acceptTime = 0;
        offers[offerId].status = "Open";

    }

    function liquidate(uint offerId) public {
        uint feeToPay = ((block.timestamp - offers[offerId].acceptTime)/(60*24))*offers[offerId].dailyFee;
        require(offers[offerId].collateral < feeToPay+offers[offerId].liquidation);

        jewel.transferFrom(address(this), offers[offerId].owner, offers[offerId].collateral);
        offers[offerId].status = "Liquidated";
    }

    }


}