// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MockMdex {

    address public swapToken;
    uint amount = 0;

    constructor(address _address) public {
        swapToken = _address;
    }

    function setAmount(uint _amount) public {
        amount = _amount;
    }

    function swapExactTokensForTokens(
        uint256 balance,
        uint256 amountOutMin,
        address[] calldata path,
        address recipient,
        uint256 expiry
    ) external returns (uint[] memory amounts) {
        if (amount > 0) {
            IERC20(swapToken).transfer(msg.sender, amount);
        }
    }


    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity){
    }
}
