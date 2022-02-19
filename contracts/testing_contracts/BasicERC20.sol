// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BasicERC20 is ERC20 {
    constructor() ERC20("ERC20Token", "ERC20") {
        _mint(msg.sender, 20000000*10**18);
    }

    function mint(address _address, uint amount) public {
        _mint(_address, amount);
    }

}