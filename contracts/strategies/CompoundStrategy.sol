// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


import "./CompoundInteractor.sol";
import "./CompleteCToken.sol";
import "..//Operatable.sol";

import "../interfaces/mdex/IMDexRouter.sol";
import "../interfaces/compound/ComptrollerInterface.sol";
import "../interfaces/compound/CTokenInterfaces.sol";
import "../interfaces/yearn/IStrategy.sol";

import "../lib/Const.sol";

contract CompoundStrategy is ProfitNotifier, CompoundInteractor, Const {
    using SafeMath for uint;

    uint256 constant mantissaScale = 10 ** 18;
    uint256 constant mantissaHalfScale = 10 ** 9;

    uint256 public ratioNumerator;
    uint256 public ratioDenominator;
    uint256 public toleranceNumerator;
    uint256 public profitComp;
    uint256 public supplied;
    uint256 public borrowed;
    // These tokens cannot be claimed by the controller
    mapping(address => bool) public unsalvagableTokens;

    modifier protectCollateral() {
        _;
        supplied = ctoken.balanceOfUnderlying(address(this));
        borrowed = ctoken.borrowBalanceCurrent(address(this));
        (, uint256 collateralFactorMantissa) = comptroller.markets(address(ctoken));
        uint256 canBorrow = supplied
        .mul(collateralFactorMantissa.div(mantissaHalfScale))
        .div(mantissaHalfScale);

        require(borrowed < canBorrow || borrowed == 0, "We would get liquidated!");
    }

    constructor(
        address _native,
        address _underlying,
        address _ctoken,
        address _vault,
        address _controller,
        address _comptroller,
        address _rewardToken,
        address _uniswap
    )

    CompoundInteractor(_vault, _controller, _native, _underlying, _ctoken, _comptroller, _uniswap) public {
        comptroller = ComptrollerInterface(_comptroller);
        rewardToken = _rewardToken;
        ctoken = CompleteCToken(_ctoken);
        ratioNumerator = 0;
        ratioDenominator = 100;
        toleranceNumerator = 0;
        swapRouter = _uniswap;

        // set these tokens to be not salvagable
        unsalvagableTokens[_underlying] = true;
        unsalvagableTokens[_ctoken] = true;
        unsalvagableTokens[_rewardToken] = true;
    }

    function depositArbCheck() public pure returns (bool) {
        return true;
    }

    /**
    * The strategy invests by supplying the underlying as a collateral and taking
    * a loan in the required ratio. The borrowed money is then re-supplied.
    */
    function invest() public override protectCollateral vaultControllerAndGeneralUser {

        (uint256 amountIn, uint256 amountOut) = investExact();
        uint256 balance = IERC20(_underlying).balanceOf(address(this));

        // get more cash from vault
        uint256 vaultLoan = 0;
        if (balance < amountIn) {
            vaultLoan = IERC20(_underlying).balanceOf(_vault);
            if (vaultLoan > 0) {
                TransferHelper.safeTransferFrom(_underlying, _vault, address(this), vaultLoan);
            }
        }
        uint256 dust = (10 ** uint256(ERC20(_underlying).decimals())).div(1e4);
        // we are out of options, now we need to roll
        uint256 suppliedRoll = 0;
        uint256 borrowedRoll = 0;
        while (suppliedRoll < amountIn) {
            uint256 nowSupplied = _supply(amountIn.sub(suppliedRoll));
            suppliedRoll = suppliedRoll.add(nowSupplied);

            uint256 nowBorrowed = borrow(amountOut.sub(borrowedRoll));
            borrowedRoll = borrowedRoll.add(nowBorrowed);
            if (nowBorrowed < dust) {
                break;
            }
        }

        // state of supply/loan will be updated by the modifier

        // return loans
        if (vaultLoan > 0) {
            balance = IERC20(_underlying).balanceOf(address(this));
            if (vaultLoan > balance) {
                vaultLoan = balance;
            }
            TransferHelper.safeTransfer(_underlying, _vault, vaultLoan);
        }
    }


    /**
    * Exits Compound and transfers everything to the vault.
    */
    function withdrawAllToVault() external override restricted protectCollateral {
        withdrawAll();
        uint balance = IERC20(_underlying).balanceOf(address(this));
        TransferHelper.safeTransfer(_underlying, _vault, balance);
    }

    function withdrawAll() internal returns (uint) {
        claimComp();
        liquidateComp();
        // now we have all balance we possibly could; the rest must be covered by a flash loan

        // borrow more cash from vault to speed up repaying the loan
        uint256 vaultLoan = IERC20(_underlying).balanceOf(_vault);
        if (vaultLoan > 0) {
            TransferHelper.safeTransferFrom(_underlying, _vault, address(this), vaultLoan);
        }
        // we always supplied more than necessary due to the set investment ratio
        // we can redeem everything

        supplied = ctoken.balanceOfUnderlying(address(this));
        borrowed = ctoken.borrowBalanceCurrent(address(this));
        uint256 dust = (10 ** uint256(ERC20(_underlying).decimals())).div(1e4);

        while (supplied > dust) {
            repayMaximum();
            redeemMaximum();
            supplied = ctoken.balanceOfUnderlying(address(this));
            borrowed = ctoken.borrowBalanceCurrent(address(this));
        }

        // return loans
        if (vaultLoan > 0) {
            uint balance = IERC20(_underlying).balanceOf(address(this));
            if (vaultLoan > balance) {
                vaultLoan = balance;
            }
            TransferHelper.safeTransfer(_underlying, _vault, vaultLoan);
        }
        return vaultLoan;
    }

    function withdrawToVault(uint256 amountUnderlying) external override restricted protectCollateral {
        if (amountUnderlying <= IERC20(_underlying).balanceOf(address(this))) {
            TransferHelper.safeTransfer(_underlying, _vault, amountUnderlying);
            return;
        }

        // we are expected to have nothing sitting around, so we should borrow
        // get more cash from vault
        uint256 vaultLoan = IERC20(_underlying).balanceOf(_vault);
        if (vaultLoan > 0) {
            TransferHelper.safeTransferFrom(_underlying, _vault, address(this), vaultLoan);
        }
        // we assume that right now, we are invested in a proper collateralization ratio
        // if the current balance (after the vault loan) is enough to repay and redeem the required
        // amount, we just do it

        repayMaximum();
        redeemMaximum();

        // by repaying and redeeming maximum, we have strictly more than we had before, and we can
        // repay the vault loan
        if (vaultLoan > 0) {
            uint balanceOfStrategy = IERC20(_underlying).balanceOf(address(this));
            if (vaultLoan > balanceOfStrategy) {
                vaultLoan = balanceOfStrategy;
            }
            TransferHelper.safeTransfer(_underlying, _vault, vaultLoan);
        }
        // if we now have enough, we can transfer the funds, otherwise the user is taking out large
        // volume of money that could destroy our collateralization ratio
        // if that is the case, we just withdraw all
        if (IERC20(_underlying).balanceOf(address(this)) < amountUnderlying) {
            withdrawAll();
            TransferHelper.safeTransfer(_underlying,
                _vault, Math.min(IERC20(_underlying).balanceOf(address(this)), amountUnderlying)
            );
            invest();
        } else {
            TransferHelper.safeTransfer(_underlying, _vault, amountUnderlying);
        }

        // if we broke the invested ratio too much, we will have to do hard work
        if (outsideTolerance()) {
            harvest();
        }

        // state of supply/loan will be updated by the modifier
    }

    function outsideTolerance() public returns (bool) {
        borrowed = ctoken.borrowBalanceCurrent(address(this));
        supplied = ctoken.balanceOfUnderlying(address(this));

        uint256 allowedLoan = supplied.mul(ratioNumerator).div(ratioDenominator);
        uint256 tolerance = supplied.mul(toleranceNumerator).div(ratioDenominator);
        return borrowed > allowedLoan.add(tolerance) || borrowed.add(tolerance) < allowedLoan;
    }


    function harvest() public override protectCollateral vaultControllerAndGeneralUser {
        if (outsideTolerance()) {
            // there is a difference between how we are invested and how we want to be invested
            // we should withdraw all and rebalance
            withdrawAll();
        }

        claimComp();
        liquidateComp();
        invest();

        // state of supply/loan will be updated by the modifier
    }

    /**
    * Redeems maximum that can be redeemed from Compound.
    */
    function redeemMaximum() internal returns (uint256) {
        // redeem as much as we can
        (, uint256 collateralFactorMantissa) = comptroller.markets(address(ctoken));

        uint256 loan = ctoken.borrowBalanceCurrent(address(this));
        uint256 supply = ctoken.balanceOfUnderlying(address(this));
        uint256 needToKeep = 0;
        if (collateralFactorMantissa > mantissaHalfScale) {
            needToKeep = loan
            .mul(mantissaHalfScale)
            .div(collateralFactorMantissa.div(mantissaHalfScale));
        }
        uint256 canRedeem = supply > needToKeep ? supply.sub(needToKeep) : 0;
        uint256 dust = (10 ** uint256(ERC20(_underlying).decimals())).div(1e4);
        if (canRedeem > dust) {
            _redeemUnderlying(canRedeem);
            return canRedeem;
        } else {
            return 0;
        }
    }

    /**
    * Borrows the amount if possible, otherwise borrows as much as we can. Returns the real amount
    * borrowed.
    */
    function borrow(uint256 amountUnderlying) internal returns (uint256) {
        // borrow as much as we can
        (, uint256 collateralFactorMantissa) = comptroller.markets(address(ctoken));
        collateralFactorMantissa = collateralFactorMantissa.div(10 ** 12);

        uint256 loan = ctoken.borrowBalanceCurrent(address(this));
        uint256 supply = ctoken.balanceOfUnderlying(address(this));
        uint256 max = supply.mul(collateralFactorMantissa).div(10 ** 6);
        uint256 canBorrow = loan >= max ? 0 : max.sub(loan);

        if (canBorrow == 0) {
            return 0;
        }

        if (amountUnderlying <= canBorrow) {
            _borrow(amountUnderlying);
            return amountUnderlying;
        } else {
            _borrow(canBorrow);
            return canBorrow;
        }
    }


    /**
    * Repay as much as we can, but at most what is needed.
    */
    function repayMaximum() internal returns (uint256) {
        uint256 balance = IERC20(_underlying).balanceOf(address(this));
        if (balance == 0) {
            // there is nothing to work with
            return 0;
        }
        uint256 loan = ctoken.borrowBalanceCurrent(address(this));
        uint256 repayAmount = Math.min(balance, loan);
        if (repayAmount > 0) {
            _repay(repayAmount);
        }
        return repayAmount;
    }

    /**
    * Salvages a token.
    */
    function salvage(address recipient, address token, uint256 amount) public onlyOperator {
        // To make sure that governance cannot come in and take away the coins
        require(!unsalvagableTokens[token], "token is defined as not salvagable");
        TransferHelper.safeTransfer(token, recipient, amount);
    }


    function setRatio(uint256 numerator,
        uint256 denominator,
        uint256 tolerance) public onlyOperator {
        require(numerator < denominator, "numerator must be smaller than denominator");
        require(tolerance < numerator, "tolerance must be smaller than numerator");
        ratioNumerator = numerator;
        ratioDenominator = denominator;
        toleranceNumerator = tolerance;
    }

    function liquidateComp() internal {
        uint256 oldBalance = IERC20(_underlying).balanceOf(address(this));
        uint256 balance = ERC20(rewardToken).balanceOf(address(this));
        if (balance > 0) {
            // we can accept 1 as minimum as this will be called by trusted roles only
            uint256 amountOutMin = 1;
            ERC20(rewardToken).approve(address(swapRouter), balance);
            address[] memory path = new address[](3);
            path[0] = address(rewardToken);
            path[1] = routerToken;
            path[2] = address(_underlying);
            IMDexRouter(swapRouter).swapExactTokensForTokens(balance,
                amountOutMin,
                path,
                address(this),
                block.timestamp + 1000
            );
            notifyProfit(
                oldBalance, IERC20(_underlying).balanceOf(address(this))
            );
        }
    }

    function investExact() public view returns (uint256, uint256) {
        require(ratioNumerator < ratioDenominator, "we could borrow infinitely");
        if (ratioNumerator == 0) {
            return (0, 0);
        }
        uint256 balance = IERC20(_underlying).balanceOf(address(this));
        uint256 totalIn = balance.mul(ratioDenominator).div(ratioDenominator.sub(ratioNumerator));
        uint256 totalOut = totalIn.sub(balance);
        return (totalIn, totalOut);
    }

    function investedUnderlyingBalance() public view returns (uint256) {
        uint256 assets = IERC20(_underlying).balanceOf(address(this)).add(supplied);
        return borrowed > assets ? 0 : assets.sub(borrowed);
    }


    function underlyingBalance() external override view returns (uint){
        return investedUnderlyingBalance();

    }

    /**
    * The operator manually adjusts  the loan contract,
    * only needs direct access to the contract method(borrow,supply,repay, redeem,rest)
    *  and can only be used in case of emergency.
    */

    function operationBorrow(uint someAmount) onlyOperator external {
        _borrow(someAmount);
    }

    function operationSupply(uint someAmount) onlyOperator external {
        _supply(someAmount);
    }

    function operationRepay(uint someAmount) onlyOperator external {
        _repay(someAmount);
    }

    function operationRedeem(uint someAmount) onlyOperator external {
        _redeemUnderlying(someAmount);
    }

    function reset() protectCollateral onlyOperator external {

    }


}
