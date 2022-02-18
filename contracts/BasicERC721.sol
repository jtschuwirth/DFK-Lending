// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicERC721 is ERC721 {
    constructor() ERC721("ERC721Token", "ERC721") {

    }

    uint[] public tokens;

    function mint(address _address) public {
        uint id = tokens.length;
        tokens.push(id);
        _mint(_address, id);
    }
}