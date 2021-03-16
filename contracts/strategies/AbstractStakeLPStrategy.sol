// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/yearn/IController.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/mdex/IMDexRouter.sol";

import "..//Operatable.sol";
import "../lib/Const.sol";
import "./AbstractLPStrategy.sol";

abstract contract AbstractStakeLPStrategy is AbstractLPStrategy, Const {
    using Address for address;
    using SafeMath for uint;

    address public pool;

    constructor(
        address _pvault,
        address _controller,
        address _underlying,
        address _pool,
        address _reward,
        address _swapRouter
    )AbstractLPStrategy(_pvault, _controller, _underlying, _reward, _swapRouter) public {
        controller = _controller;
        pool = _pool;

    }

    function invest() public vaultControllerAndGeneralUser override {
        uint _want = IERC20(_underlying).balanceOf(address(this));
        if (_want > 0) {
            TransferHelper.safeApprove(_underlying, pool, 0);
            TransferHelper.safeApprove(_underlying, pool, _want);
            stake(_want);
        }

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
        exit();
    }

    function withdrawFromPool(uint _amount) public onlyOperator {
        if (_amount != 0) {
            withdraw(_amount);
        }
    }

    function harvest() override public vaultControllerAndGeneralUser {
        uint _beforeBal = IERC20(_underlying).balanceOf(address(this));
        getReward();
        _liquidateReward();
        uint _afterBal = IERC20(_underlying).balanceOf(address(this));
        if (_afterBal > 0) {
            notifyProfit(_beforeBal, _afterBal);
            invest();
        }
    }

    function _withdrawSome(uint256 _amount) internal returns (uint) {
        withdraw(_amount);
        return _amount;
    }

    function balanceOfWant() public view returns (uint) {
        return IERC20(_underlying).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint) {
        return balanceOf(address(this));
    }

    function underlyingBalance() public override view returns (uint) {
        return balanceOfWant()
        .add(balanceOfPool());
    }


    function withdraw(uint) internal virtual;

    function getReward() internal virtual;

    function stake(uint) internal virtual;

    function balanceOf(address) internal virtual view returns (uint);

    function exit() internal virtual;


}
