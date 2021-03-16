// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/IMasterChef.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MockMasterChef is IMasterChef {

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accWhtPerShare;
    }

    PoolInfo[] private  _poolInfo;

    mapping(uint256 => mapping(address => UserInfo))  private _userInfo;

    using SafeMath for uint256;

    IERC20 public reward;

    mapping(address => uint256) private _balances;


    constructor(address _reward) public {
        reward = IERC20(_reward);
    }


    function deposit(uint256 _pid, uint256 _amount) public override {
        PoolInfo storage pool = _poolInfo[_pid];
        _balances[msg.sender] = _balances[msg.sender].add(_amount);
        UserInfo storage user = _userInfo[_pid][msg.sender];
        if (_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accWhtPerShare).div(1e12);

    }

    function withdraw(uint256 _pid, uint256 _amount) public override {
        PoolInfo storage pool = _poolInfo[_pid];
        UserInfo storage user = _userInfo[_pid][msg.sender];
        _balances[msg.sender] = _balances[msg.sender].sub(_amount);
        user.amount = user.amount.sub(_amount);
        pool.lpToken.transfer(msg.sender, _amount);
    }

    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public {
        _withUpdate;
        require(address(_lpToken) != address(0), "lpToken is the zero address");
        _poolInfo.push(PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        lastRewardBlock : block.number,
        accWhtPerShare : 0
        }));
    }

    function pending(uint256 _pid, address _user) external override view returns (uint256){
        _pid;
        _user;
        return 1e18;
    }

    function userInfo(uint256 _pid, address _user) external override view returns (uint256 amount, uint256 rewardDebt){
        _pid;
        _user;
        PoolInfo memory pool = _poolInfo[_pid];
        pool;
        UserInfo memory user = _userInfo[_pid][msg.sender];
        return (user.amount, user.rewardDebt);
    }

    function poolInfo(uint256 _pid) external override view returns (address lpToken, uint256, uint256, uint256){
        PoolInfo memory pool = _poolInfo[_pid];
        return (address(pool.lpToken),
        pool.allocPoint,
        pool.lastRewardBlock,
        pool.accWhtPerShare);
    }

    function emergencyWithdraw(uint256 _pid) external override {
        PoolInfo memory pool = _poolInfo[_pid];
        UserInfo memory user = _userInfo[_pid][msg.sender];
        withdraw(_pid, user.amount);
    }

}