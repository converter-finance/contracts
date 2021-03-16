// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;


import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/mdex/IMDexRouter.sol";
import "../interfaces/yearn/IVault.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/mdex/IMdexPair.sol";
import "./ProfitNotifier.sol";

abstract contract AbstractLPStrategy is ProfitNotifier {
    using SafeMath for uint;

    mapping(address => address[]) public mdexRoutes;

    constructor(
        address _vault,
        address _controller,
        address _underlying,
        address _rewardToken,
        address _swapRouter
    ) ProfitNotifier(_vault, _controller, _underlying, _swapRouter) public {
        rewardToken = _rewardToken;
    }

    function setLiquidation(
        address [] memory _routeToToken0, address [] memory _routeToToken1
    ) public onlyOperator {
        address lpToken0 = IMdexPair(underlying()).token0();
        address lpToken1 = IMdexPair(underlying()).token1();
        mdexRoutes[lpToken0] = _routeToToken0;
        mdexRoutes[lpToken1] = _routeToToken1;
    }


    function _liquidateReward() internal {

        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));

        address lpToken0 = IMdexPair(underlying()).token0();
        address lpToken1 = IMdexPair(underlying()).token1();

        address[] memory routesToken0;
        address[] memory routesToken1;

        routesToken0 = mdexRoutes[lpToken0];
        routesToken1 = mdexRoutes[lpToken1];

        uint _beforeBal = IERC20(underlying()).balanceOf(address(this));
        if (rewardBalance > 0 // we have tokens to swap
        && routesToken0.length > 1 // and we have a route to do the swap
            && routesToken1.length > 1 // and we have a route to do the swap
        ) {
            if (rewardToken != lpToken0) {
                IERC20(rewardToken).approve(swapRouter, 0);
                IERC20(rewardToken).approve(swapRouter, rewardBalance);

                IMDexRouter(swapRouter).swapExactTokensForTokens(
                    rewardBalance,
                    1,
                    routesToken0,
                    address(this),
                    block.timestamp
                );
            }
            uint256 lpToken0Amount = IERC20(lpToken0).balanceOf(address(this));

            IERC20(lpToken0).approve(swapRouter, 0);
            IERC20(lpToken0).approve(swapRouter, lpToken0Amount);

            lpToken0Amount = lpToken0Amount.div(2);
            IMDexRouter(swapRouter).swapExactTokensForTokens(
                lpToken0Amount,
                1,
                routesToken1,
                address(this),
                block.timestamp
            );
            uint256 lpToken1Amount = IERC20(lpToken1).balanceOf(address(this));

            IERC20(lpToken1).approve(swapRouter, 0);
            IERC20(lpToken1).approve(swapRouter, lpToken1Amount);

            uint256 liquidity;
            (,, liquidity) = IMDexRouter(swapRouter).addLiquidity(
                lpToken0,
                lpToken1,
                lpToken0Amount,
                lpToken1Amount,
                1, // we are willing to take whatever the pair gives us
                1, // we are willing to take whatever the pair gives us
                address(this),
                block.timestamp
            );
        }
        uint _afterBal = IERC20(_underlying).balanceOf(address(this));
        if (_afterBal > 0) {
            notifyProfit(_beforeBal, _afterBal);
        }
    }
}