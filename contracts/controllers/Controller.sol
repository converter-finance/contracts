// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/yearn/IVault.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/mdex/IMDexRouter.sol";
import "../interfaces/yearn/IController.sol";

import "../lib/Const.sol";
import "../ContractWhiteList.sol";
import "../lib/TransferHelper.sol";

contract Controller is IController, ContractWhiteList, Const {
    using Address for address;
    using SafeMath for uint256;

    uint public constant MAX_FEE = 10000;

    address public swapRouter;
    address public rewards;
    mapping(address => bool) public vaults;
    uint public salvageFeeRate;

    address private _feeManager;

    constructor(address _pFeeManager) ContractWhiteList() public {
        _feeManager = _pFeeManager;
        salvageFeeRate = 3000;
    }

    function setSalvageFeeRate(uint _feeRate) onlyOperator public {
        require(_feeRate < MAX_FEE / 2, "fee rate < max/2");
        salvageFeeRate = _feeRate;
    }

    function addVaultAndStrategy(address _vault, address _strategy) onlyOperator external {
        require(_vault != address(0), "new vault shouldn't be empty");
        require(!vaults[_vault], "vault already exists");
        require(_strategy != address(0), "new strategy shouldn't be empty");

        vaults[_vault] = true;
        // no need to protect against sandwich, because there will be no call to withdrawAll
        // as the vault and strategy is brand new
        IVault(_vault).setStrategy(_strategy);
    }

    function setSwapRouter(address _address) onlyOperator public {
        swapRouter = _address;
    }


    function setFeeManager(address _address) onlyOperator public {
        _feeManager = _address;
    }

    function hasVault(address _vault) external view returns (bool) {
        return vaults[_vault];
    }

    function withdrawAllToVault(address _vault) onlyOperator public {
        IStrategy(IVault(_vault).strategy()).withdrawAllToVault();
    }

    function inCaseTokensGetStuck(address _token, uint _amount) onlyOperator public {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function inCaseStrategyTokenGetStuck(address _strategy, address _token) onlyOperator public {
        IStrategy(_strategy).salvageToken(_token);
    }

    // Only allows to withdraw non-core strategy tokens ~ this is over and above normal yield
    function salvageToken(address _strategy, address _token, address routerToken) onlyOperator public {

        address _underlying = IStrategy(_strategy).underlying();
        require(_underlying != _token, "! _underlying");
        IStrategy(_strategy).salvageToken(_token);

        uint _before = IERC20(_underlying).balanceOf(address(this));
        uint _salvageBal = IERC20(_token).balanceOf(address(this));
        TransferHelper.safeApprove(_token, swapRouter, _salvageBal);

        address[] memory path = new address[](3);
        path[0] = address(_token);
        path[1] = routerToken;
        path[2] = address(_underlying);
        IMDexRouter(swapRouter).swapExactTokensForTokens(
            _salvageBal,
            1,
            path,
            address(this),
            block.timestamp + 100
        );

        uint _after = IERC20(_underlying).balanceOf(address(this));
        if (_after > 0) {
            uint _amount = _after.sub(_before);
            uint _fee = _amount.mul(salvageFeeRate).div(MAX_FEE);
            TransferHelper.safeTransfer(_underlying, _feeManager, _fee);
            TransferHelper.safeTransfer(_underlying, _strategy, _amount.sub(_fee));
        }
    }
    //Some tokens cannot be traded , only be extracted by the operator
    function operatorSalvageToken(address _strategy, address _token) onlyOperator public {
        address _underlying = IStrategy(_strategy).underlying();
        require(_underlying != _token, "! _underlying");
        IStrategy(_strategy).salvageToken(_token);
        uint _amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(operator, _amount);
    }

    //Do not ban access to the user, need to be in the whitelist contract address to be able to access
    function check(address _target) external override view returns (bool) {
        if (isContract(_target)) {
            return contractWhiteList[_target];
        }
        return true;
    }

    function withdraw(address _vault, uint _amount) onlyOperator public {
        IStrategy(IVault(_vault).strategy()).withdrawToVault(_amount);
    }

    function underlying(address vault) external override view returns (address){
        return IVault(vault).underlying();
    }

    function harvest(address _vault) onlyOperator external {
        IStrategy(IVault(_vault).strategy()).harvest();
    }

    function feeManager() external override view returns (address){
        return _feeManager;
    }

}
