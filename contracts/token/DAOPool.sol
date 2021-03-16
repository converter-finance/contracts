// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./IRewardPool.sol";

import "..//Operatable.sol";
import "../lib/Const.sol";
import "./RewardToken.sol";
import "./LPTokenWrapper.sol";
import "./Reservoir.sol";
import "../lib/TransferHelper.sol";


contract DAOPool is Operatable, IRewardPool, Const {
    using SafeMath for uint;

    uint public pid;
    address public reservoirAddress;

    constructor(
        address _reservoirAddress,
        uint _pid
    ) public Operatable(){
        reservoirAddress = _reservoirAddress;
        pid = _pid;
    }

    function extractDAO(address _token) public onlyOperator {
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        if (_balance > 0) {
            TransferHelper.safeTransfer(_token, operator, _balance);
            Reservoir(reservoirAddress).updatePool(pid);
        }
    }

    function updateDAOReward() external {
        Reservoir(reservoirAddress).updatePool(pid);
    }

    function notifyRewardAmount(uint256 reward)
    external
    override {
    }

    function setPoolId(uint256 _pid) onlyOperator external override {
        pid = _pid;
    }

    function setReservoir(address _reservoir) onlyOperator public {
        require(_reservoir != address(0), "reservoir is not 0");
        reservoirAddress = _reservoir;
    }
}
