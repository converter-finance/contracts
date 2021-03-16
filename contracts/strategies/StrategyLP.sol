// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/depoist/IRewards.sol";
import "../interfaces/yearn/IController.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/mdex/IMDexRouter.sol";

import "..//Operatable.sol";
import "../lib/Const.sol";
import "./AbstractStakeLPStrategy.sol";
import "../interfaces/depoist/IRewards.sol";

contract StrategyLP is AbstractStakeLPStrategy {

    constructor(
        address _pvault,
        address _controller,
        address _underlying,
        address _pool,
        address _reward,
        address _swapRouter
    )AbstractStakeLPStrategy(_pvault, _controller, _underlying, _pool, _reward, _swapRouter) public {

    }

    function withdraw(uint _amount) internal override {
        IRewards(pool).withdraw(_amount);
    }

    function getReward() internal override {
        IRewards(pool).getReward();
    }

    function stake(uint _want) internal override {
        IRewards(pool).stake(_want);
    }

    function balanceOf(address) internal override view returns (uint){
        return IRewards(pool).balanceOf(address(this));
    }

    function exit() internal override {
        IRewards(pool).exit();

    }


}
