// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../lib/TransferHelper.sol";

contract LPTokenWrapper {
    using SafeMath for uint;

    address public lpToken;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        TransferHelper.safeTransferFrom(lpToken, msg.sender, address(this), amount);
    }

}
