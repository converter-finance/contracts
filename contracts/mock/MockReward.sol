// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/depoist/IRewards.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockReward  {
    using SafeMath for uint256;

    IERC20 public underlying;

    IERC20 public reward;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;


    constructor(address _stake, address _reward) public {
        underlying = IERC20(_stake);
        reward = IERC20(_reward);
    }


    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        underlying.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        underlying.transfer(msg.sender, amount);
    }

    function getReward() public {
        reward.transfer(msg.sender, 10000);

    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }
}