// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;


import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/mdex/IMdexPair.sol";

contract MockMdexPair is ERC20 {
    address public token0;
    address public token1;

    constructor(address _token0, address _token1) public ERC20("LP", "LP"){
        token0 = _token0;
        token1 = _token1;

    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

}