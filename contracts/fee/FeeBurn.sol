// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../token/RewardToken.sol";
import "..//Operatable.sol";
import "../interfaces/mdex/IMDexRouter.sol";
import "../lib/TransferHelper.sol";

contract FeeBurn is Operatable {
    using SafeMath for uint;

    address public immutable USDT;

    uint public amountIn;
    address public rewardToken;
    address public swapRouter;

    constructor(address usdt, address _rewardToken) Operatable() public {
        rewardToken = _rewardToken;
        USDT = usdt;
    }

    function setAmountIn(uint256 _newIn) public onlyOperator {
        amountIn = _newIn;
    }

    function setSwapRouter(address _address) onlyOperator external {
        swapRouter = _address;
    }

    function swapToken() onlyOperator public returns (uint){
        require(swapRouter != address(0), "swapRouter=0");
        uint balanceUSDT = IERC20(USDT).balanceOf(address(this));
        uint usdtAmount = amountIn;
        if (balanceUSDT < usdtAmount) {
            usdtAmount = balanceUSDT;
        }

        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = rewardToken;

        TransferHelper.safeApprove(USDT, swapRouter, usdtAmount);
        IMDexRouter(swapRouter).swapExactTokensForTokens(
            usdtAmount,
            1,
            path,
            address(this),
            block.timestamp + 100
        );

        return IERC20(rewardToken).balanceOf(address(this));
    }

    function burnToken() public {
        uint _amount = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > 0) {
            RewardToken(rewardToken).burn(_amount);
        }
    }

    function salvageToken(address _token) onlyOperator public {
        require(_token != rewardToken, "not reward token");
        uint balance = IERC20(_token).balanceOf(address(this));
        TransferHelper.safeTransfer(_token, operator, balance);
    }

}