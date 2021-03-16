// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/mdex/IMDexRouter.sol";
import "../interfaces/yearn/IVault.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/mdex/IMdexPair.sol";
import "./AbstractLPStrategy.sol";

contract MdexBoardroomLPStrategy is AbstractLPStrategy {
    using SafeMath for uint;

    address public rewardPool;
    uint public poolID;

    constructor(
        address _vault,
        address _controller,
        address _underlying,
        address _rewardPool,
        uint256 _poolID,
        address _rewardToken,
        address _swapRouter
    ) AbstractLPStrategy(_vault, _controller, _underlying, _rewardToken, _swapRouter) public {
        address _lpt;
        rewardPool = _rewardPool;
        rewardToken = _rewardToken;
        (_lpt,,,) = IMasterChef(rewardPool).poolInfo(_poolID);
        require(_lpt == underlying(), "Pool Info does not match underlying");

        poolID = _poolID;
    }

    function balanceOfPool() public view returns (uint256 bal) {
        (bal,) = IMasterChef(rewardPool).userInfo(poolId(), address(this));
    }

    function exitRewardPool() internal {
        uint256 bal = balanceOfPool();
        if (bal != 0) {
            IMasterChef(rewardPool).withdraw(poolId(), bal);
        }
    }

    function enterRewardPool() internal {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
        TransferHelper.safeApprove(underlying(), rewardPool, 0);
        TransferHelper.safeApprove(underlying(), rewardPool, entireBalance);
        IMasterChef(rewardPool).deposit(poolId(), entireBalance);
    }

    function emergencyWithdraw(uint _amount) public onlyOperator {
        if (_amount != 0) {
            IMasterChef(rewardPool).emergencyWithdraw(poolId());
        }
    }

    function invest() public vaultControllerAndGeneralUser override {
        // this check is needed, because most of the SNX reward pools will revert if
        // you try to stake(0).
        if (IERC20(underlying()).balanceOf(address(this)) > 0) {
            enterRewardPool();
        }
    }

    function withdrawAllToVault() public override restricted {
        if (rewardPool != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        TransferHelper.safeTransfer(underlying(), vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    function withdrawToVault(uint256 amount) public override restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > entireBalance) {
            // While we have the check above, we still using SafeMath below
            // for the peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(entireBalance);
            uint256 toWithdraw = Math.min(balanceOfPool(), needToWithdraw);
            IMasterChef(rewardPool).withdraw(poolId(), toWithdraw);
        }

        TransferHelper.safeTransfer(underlying(), vault(), amount);
    }

    /*
    *   Note that we currently do not have a mechanism here to include the
    *   amount of reward that is accrued.
    */
    function underlyingBalance() external override view returns (uint256) {
        if (rewardPool == address(0)) {
            return IERC20(underlying()).balanceOf(address(this));
        }
        // Adding the amount locked in the reward pool and the amount that is somehow in this contract
        // both are in the units of "underlying"
        // The second part is needed because there is the emergency exit mechanism
        // which would break the assumption that all the funds are always inside of the reward pool
        return balanceOfPool().add(IERC20(underlying()).balanceOf(address(this)));
    }

    function harvest() external override vaultControllerAndGeneralUser {
        getPoolReward();
        _liquidateReward();
        invest();
    }

    // deposit 0 can claim all pending amount
    function getPoolReward() internal {
        IMasterChef(rewardPool).deposit(poolId(), 0);
    }

    function poolId() public view returns (uint256) {
        return poolID;
    }

}
