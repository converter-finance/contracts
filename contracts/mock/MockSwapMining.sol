// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/mdex/ISwapMining.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MockSwapMining is ISwapMining {

    address public reward;

    constructor(address _reward) public {
        reward = _reward;
    }


    function takerWithdraw() external override {
        IERC20(reward).transfer(msg.sender, 10000);
    }

}