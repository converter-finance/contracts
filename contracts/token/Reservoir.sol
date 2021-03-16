// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "..//Operatable.sol";
import "../lib/Const.sol";
import "../lib/TransferHelper.sol";
import "../ContractWhiteList.sol";

import "./RewardToken.sol";
import "./IRewardPool.sol";


contract Reservoir is ContractWhiteList, Const {
    using SafeMath for uint;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Events
    event Recovered(address token, uint256 amount);

    struct PoolInfo {
        uint256 allocPoint; // How many allocation points assigned to this pool.
        address contractAddress;
        uint256 lastRewardBlock;
    }

    uint256 constant public MIN_TOKEN_REWARD = 0.26 * 1e18;
    // set default 30 days
    uint immutable public duration;

    uint fundLastRewardBlock;
    RewardToken public rewardToken;

    uint public fundRate = 0.15e18;
    uint public liquidityRate = 0.85e18;
    uint public tokenPerBlock = 2.6 * 1e18;
    PoolInfo[] public poolInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    uint256 decrement;
    // The block number when token mining starts.
    uint256 public startBlock;
    uint256 public periodEndBlock;

    EnumerableSet.AddressSet private fundAddrs;

    constructor(
        RewardToken _rewardToken,
        uint256 _startBlock,
        uint256 _duration
    ) ContractWhiteList() public {
        periodEndBlock = _startBlock.add(_duration);
        require(periodEndBlock > block.number, "end is wrong");
        rewardToken = _rewardToken;
        startBlock = _startBlock;
        fundLastRewardBlock = _startBlock;

        duration = _duration;
    }

    function mintToken() onlyOwner public {
        rewardToken.mint(address(this));
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        address _contractAddress,
        uint256 _allocPoint
    ) public onlyOperator adjustProduct {
        require(_contractAddress != address(0), "address not 0");
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo memory pool = poolInfo[pid];
            require(pool.contractAddress != _contractAddress, "contract is exist");
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        //Token distribution can take place 12 hours after the pool is added
        uint256 halfDay = DAY.div(2);
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo(
            {
            allocPoint : _allocPoint,
            contractAddress : _contractAddress,
            lastRewardBlock : lastRewardBlock.add(halfDay)
            }
            )
        );
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint
    ) public onlyOperator adjustProduct {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    modifier adjustProduct()  {
        if (block.number > startBlock && block.number >= periodEndBlock) {
            if (tokenPerBlock > MIN_TOKEN_REWARD) {
                tokenPerBlock = tokenPerBlock.mul(93).div(100);
            }
            if (tokenPerBlock < MIN_TOKEN_REWARD) {
                tokenPerBlock = MIN_TOKEN_REWARD;
            }
            periodEndBlock = block.number.add(duration);
        }
        _;
    }

    function calRate(uint _amount, uint rate) public pure returns (uint){
        return _amount.mul(rate).div(1e18);
    }

    // Distribute the output of a cycle in advance
    //The token is distributed one day in advance
    function distributionToken() adjustProduct public {
        if (block.number < startBlock) {
            return;
        }
        uint length = poolInfo.length;
        for (uint pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    function updatePool(uint256 _pid) adjustProduct public {
        if (block.number < startBlock) {
            return;
        }
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.lastRewardBlock > block.number) {
            return;
        }
        uint multiplier = 1;
        // The number of tokens for one day is distributed to a pool
        if (periodEndBlock > block.number) {
            multiplier = block.number - pool.lastRewardBlock + DAY;
        }
        uint _reward = multiplier.mul(tokenPerBlock);
        uint liquidityFund = calRate(_reward, liquidityRate);

        if (pool.allocPoint > 0) {
            uint256 poolReward = liquidityFund.mul(pool.allocPoint).div(totalAllocPoint);
            safeTokenTransfer(pool.contractAddress, poolReward);
            IRewardPool(pool.contractAddress).notifyRewardAmount(poolReward);
        }
        pool.lastRewardBlock = block.number + DAY;
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough dex.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = rewardToken.balanceOf(address(this));
        if (_amount > tokenBal) {
            rewardToken.transfer(_to, tokenBal);
        } else {
            rewardToken.transfer(_to, _amount);
        }
    }

    // Distribute tokens according to teh speed of the block
    function claimFund() onlyOperator adjustProduct external {
        if (block.number < startBlock) {
            return;
        }
        if (block.number <= fundLastRewardBlock) {
            return;
        }
        uint256 multiplier = block.number - fundLastRewardBlock;
        uint256 _reward = multiplier.mul(tokenPerBlock);
        uint fund = calRate(_reward, fundRate);

        uint256 perFund = fund.div(fundAddrs.length());
        for (uint256 i = 0; i < fundAddrs.length() - 1; i++) {
            TransferHelper.safeTransfer(address(rewardToken), fundAddrs.at(i), perFund);
        }
        uint256 remainFund = fund.sub(perFund.mul(fundAddrs.length() - 1));
        TransferHelper.safeTransfer(address(rewardToken), fundAddrs.at(fundAddrs.length() - 1), remainFund);
        fund = 0;
        fundLastRewardBlock = block.number;
    }


    function addFund(address _addr) onlyOperator public {
        require(fundAddrs.length() < 100, "less 100");
        require(_addr != address(0), "address not 0");
        fundAddrs.add(_addr);
    }

    function removeFund(address _addr) onlyOperator public {
        fundAddrs.remove(_addr);
    }

    function contains(address _addr) public view returns (bool){
        return fundAddrs.contains(_addr);
    }

    function fundAddrsLength() public view returns (uint256){
        return fundAddrs.length();
    }

    function setFundRate(uint256 _rate) onlyOperator public {
        require(_rate <= 0.15e18, "rate too large");
        fundRate = _rate;
        liquidityRate = MAX_RATE.sub(fundRate);
    }

    function setLiquidityRate(uint _rate) onlyOperator external {
        require(_rate >= 0.85e18, "rate too samll");
        liquidityRate = _rate;
        fundRate = MAX_RATE.sub(liquidityRate);
    }

    //Do not ban access to the user, need to be in the whitelist contract address to be able to access
    function check(address _target) external view returns (bool) {
        if (_target.isContract()) {
            return contractWhiteList[_target];
        }
        return true;
    }


}
