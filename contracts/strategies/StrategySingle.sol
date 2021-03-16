// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "./AbstractStakeSingleStrategy.sol";
import "../interfaces/depoist/IRewards.sol";

contract StrategySingle is AbstractStakeSingleStrategy {

    constructor(
        address _controller,
        address _underlying,
        address _pvault,
        address _pool,
        address _reward,
        address _swapRouter
    )AbstractStakeSingleStrategy(_controller, _underlying, _pvault, _pool, _reward, _swapRouter) public {

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
