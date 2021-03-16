// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";


contract RewardToken is ERC20, ERC20Burnable, Ownable {

    uint public constant MAX = 48800000 * 1e18;

    constructor () public ERC20("CON", "CON") {
    }

    function mint(address _to) public onlyOwner {
        require(totalSupply() == 0, "only mint once");
        _mint(_to, MAX);
    }

}