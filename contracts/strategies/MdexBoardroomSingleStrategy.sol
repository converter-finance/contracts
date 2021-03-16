// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/yearn/IController.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/mdex/IMDexRouter.sol";
import "../interfaces/IMasterChef.sol";
import "..//Operatable.sol";
import "../lib/Const.sol";
import "./ProfitNotifier.sol";

contract MdexBoardroomSingleStrategy is ProfitNotifier, Const {
    using Address for address;
    using SafeMath for uint;

    address public pool;
    uint public poolID;

    constructor(
        address _pvault,
        address _controller,
        address _underlying,
        address _pool,
        uint256 _poolID,
        address _reward,
        address _swapRouter
    )ProfitNotifier(_pvault, _controller, _underlying, _swapRouter) public {
        address _lpt;
        controller = _controller;
        pool = _pool;
        rewardToken = _reward;
        poolID = _poolID;
        (_lpt,,,) = IMasterChef(pool).poolInfo(poolID);
        require(_lpt == underlying(), "Pool Info does not match underlying");
    }

    function invest() public vaultControllerAndGeneralUser override {
        uint _want = IERC20(_underlying).balanceOf(address(this));
        if (_want > 0) {
            enterRewardPool();
        }

    }

    function exitRewardPool() internal {
        uint256 bal = balanceOfPool();
        if (bal != 0) {
            IMasterChef(pool).withdraw(poolId(), bal);
        }
    }

    function emergencyWithdraw(uint _amount) public onlyOperator {
        if (_amount != 0) {
            IMasterChef(pool).emergencyWithdraw(_amount);
        }
    }

    function enterRewardPool() internal {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
        TransferHelper.safeApprove(underlying(), pool, 0);
        TransferHelper.safeApprove(underlying(), pool, entireBalance);
        IMasterChef(pool).deposit(poolId(), entireBalance);
    }


    function withdrawAllToVault() restricted external override {
        _withdrawAllFromPool();
        uint balance = IERC20(_underlying).balanceOf(address(this));
        TransferHelper.safeTransfer(_underlying, _vault, balance);
    }

    // Withdraw partial funds, normally used with a vault withdrawal
    function withdrawToVault(uint _amount) restricted external override {
        uint tmpAmount = _amount;
        uint _balance = IERC20(_underlying).balanceOf(address(this));
        if (_balance < tmpAmount) {
            tmpAmount = _withdrawSome(tmpAmount.sub(_balance));
            tmpAmount = tmpAmount.add(_balance);
        }
        TransferHelper.safeTransfer(_underlying, _vault, tmpAmount);
    }

    function _withdrawAllFromPool() internal {
        exitRewardPool();
    }

    function harvest() override vaultControllerAndGeneralUser public {
        uint _beforeBal = IERC20(_underlying).balanceOf(address(this));
        getPoolReward();
        uint _rewardBalance = IERC20(rewardToken).balanceOf(address(this));
        if (_rewardBalance > 0 && _underlying != rewardToken) {
            TransferHelper.safeApprove(rewardToken, swapRouter, _rewardBalance);
            address[] memory path = new address[](3);
            path[0] = address(rewardToken);
            path[1] = routerToken;
            path[2] = address(_underlying);
            IMDexRouter(swapRouter).swapExactTokensForTokens(
                _rewardBalance,
                1,
                path,
                address(this),
                block.timestamp + 100
            );

        }
        uint _afterBal = IERC20(_underlying).balanceOf(address(this));
        if (_afterBal > 0) {
            notifyProfit(_beforeBal, _afterBal);
            invest();
        }
    }

    // deposit 0 can claim all pending amount
    function getPoolReward() internal {
        IMasterChef(pool).deposit(poolId(), 0);
    }

    function _withdrawSome(uint256 _amount) internal returns (uint) {
        IMasterChef(pool).withdraw(poolId(), _amount);
        return _amount;
    }

    function balanceOfWant() public view returns (uint) {
        return IERC20(_underlying).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint bal) {
        (bal,) = IMasterChef(pool).userInfo(poolId(), address(this));
        return bal;
    }

    function underlyingBalance() public override view returns (uint) {
        return balanceOfWant()
        .add(balanceOfPool());
    }

    function poolId() public view returns (uint256) {
        return poolID;
    }
}
