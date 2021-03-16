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


contract RewardPool is LPTokenWrapper, Operatable, IRewardPool, Const {
    using SafeMath for uint;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardDenied(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    uint256 constant MAX_EXIT_FEE = 1000;

    address public rewardToken;
    uint public duration;
    uint public periodFinish;
    uint public rewardRate;
    uint public lastUpdateTime;
    uint public rewardPerTokenStored;
    uint public exitFee;
    address public feeManager;
    uint public exitFund;
    uint public pid;
    address public reservoirAddress;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => bool) smartContractStakers;

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _reservoirAddress,
        address _rewardToken,
        address _lpToken,
        address _feeManager
    ) public
    Operatable(){
        reservoirAddress = _reservoirAddress;
        rewardToken = _rewardToken;
        lpToken = _lpToken;
        feeManager = _feeManager;
        //Dispatch every other day in line with the reservoir
        duration = DAY;
    }

    function setExitFee(uint _fee) public onlyOperator {
        require(_fee <= 3, "fee too much");
        exitFee = _fee;
    }

    function setDuration(uint _duration) public onlyOperator {
        duration = _duration;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.number, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
        rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(lastUpdateTime)
            .mul(rewardRate)
            .mul(1e18)
            .div(totalSupply())
        );
    }

    function earned(address account) public view returns (uint256) {
        return
        balanceOf(account)
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount) public override updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) {
        _withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function _withdraw(uint256 amount) private {
        require(amount > 0, "Cannot withdraw 0");
        uint exitAmount = 0;
        if (exitFee > 0) {
            exitAmount = amount.mul(exitFee).div(MAX_EXIT_FEE);
            exitFund = exitFund.add(exitAmount);
        }
        uint userAmount = amount.sub(exitAmount);

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        TransferHelper.safeTransfer(lpToken, msg.sender, userAmount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = _safeTransferReward(rewardToken, msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
            Reservoir(reservoirAddress).updatePool(pid);
        }
    }

    function _safeTransferReward(address _token, address _user, uint _amount) private returns (uint) {
        IERC20 transferToken = IERC20(_token);
        uint remaining = transferToken.balanceOf(address(this));
        if (_amount <= remaining) {
            TransferHelper.safeTransfer(_token, _user, _amount);
            return 0;
        } else {
            TransferHelper.safeTransfer(_token, _user, remaining);
            return _amount.sub(remaining);
        }

    }

    function emergencyWithdraw() external {
        rewards[msg.sender] = 0;
        userRewardPerTokenPaid[msg.sender] = rewardPerToken();
        uint amount = balanceOf(msg.sender);
        _withdraw(amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    function claimFee() public {
        TransferHelper.safeTransfer(lpToken, feeManager, exitFund);
        exitFund = 0;
    }

    function notifyRewardAmount(uint256 reward)
    external
    override
    updateReward(address(0))
    {
        require(msg.sender == operator || msg.sender == reservoirAddress, "only controller and reservoir");

        require(reward < uint(- 1) / 1e18, "the notified reward cannot invoke multiplication overflow");

        if (block.number >= periodFinish) {
            rewardRate = reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(block.number);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(duration);
        }
        lastUpdateTime = block.number;
        periodFinish = block.number.add(duration);
        emit RewardAdded(reward);
    }

    function setPoolId(uint256 _pid) onlyOperator external override {
        pid = _pid;
    }

    function setReservoir(address _reservoir) onlyOperator public {
        require(_reservoir != address(0), "reservoir is not 0");
        reservoirAddress = _reservoir;
    }
}
