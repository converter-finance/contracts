// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockReceipt is ERC20 {
    constructor(
        string memory name, string memory symbol, uint8 decimals, uint256 total
    )ERC20(name, symbol) public {

        _mint(msg.sender, total);
    }
    function underlyingAssetAddress() external view returns (address){
        return address(this);
    }

    function redeem(uint256 _amount) public {

    }

}