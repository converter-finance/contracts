// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ProfitNotifier.sol";
import "./CompleteCToken.sol";
import "../interfaces/weth/WETH9.sol";
import "../interfaces/compound/ICEther.sol";
import "../lib/TransferHelper.sol";

abstract contract CompoundInteractor is ProfitNotifier, ReentrancyGuard {
    using SafeMath for uint;

    IERC20 public _weth;
    CompleteCToken public ctoken;
    ComptrollerInterface public comptroller;
    address [] public claimMarkets;

    constructor(
        address _pvault,
        address _controller,
        address _native,
        address _want,
        address _ctoken,
        address _comptroller,
        address _swapRouter
    ) public ProfitNotifier(_pvault, _controller, _want, _swapRouter) {
        // Comptroller:
        comptroller = ComptrollerInterface(_comptroller);
        _weth = IERC20(_native);
        ctoken = CompleteCToken(_ctoken);

        // Enter the market
        address[] memory cTokens = new address[](1);
        cTokens[0] = _ctoken;
        comptroller.enterMarkets(cTokens);
    }



    function setClaimMarkers(address[] memory _markets) external onlyOperator {
        claimMarkets = _markets;

    }
    /**
    * Supplies to Compound
    */
    function _supply(uint256 amount) internal returns (uint256) {
        uint256 balance = IERC20(_underlying).balanceOf(address(this));
        if (amount < balance) {
            balance = amount;
        }
        TransferHelper.safeApprove(_underlying, address(ctoken), 0);
        TransferHelper.safeApprove(_underlying, address(ctoken), balance);
        uint256 mintResult = ctoken.mint(balance);
        require(mintResult == 0, "Supplying failed");
        return balance;
    }

    /**
    * Borrows against the collateral
    */
    function _borrow(
        uint256 amountUnderlying
    ) internal {
        // Borrow DAI, check the DAI balance for this contract's address
        uint256 result = ctoken.borrow(amountUnderlying);
        require(result == 0, "Borrow failed");
    }


    /**
    * Repays a loan
    */
    function _repay(uint256 amountUnderlying) internal {
        TransferHelper.safeApprove(_underlying, address(ctoken), 0);
        TransferHelper.safeApprove(_underlying, address(ctoken), amountUnderlying);
        ctoken.repayBorrow(amountUnderlying);
        TransferHelper.safeApprove(_underlying, address(ctoken), 0);
    }


    /**
    * Redeem liquidity in underlying
    */
    function _redeemUnderlying(uint256 amountUnderlying) internal {
        if (amountUnderlying > 0) {
            ctoken.redeemUnderlying(amountUnderlying);
        }
    }


    function claimComp() public {
        if (claimMarkets.length > 0) {
            comptroller.claimComp(address(this), claimMarkets);
        }
    }

}
