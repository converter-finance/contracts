// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/yearn/IController.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/yearn/IVault.sol";
import "..//Operatable.sol";
import "../lib/TransferHelper.sol";

abstract contract Vault is IVault, ERC20, Operatable, ReentrancyGuard {
    using Address for address;
    using SafeMath for uint;

    uint256 public constant withdrawalMax = 10000;
    uint public constant max = 10000;

    uint public min = 9500;
    address public controller;
    uint256 public withdrawalFee = 0;

    address private _underlying;
    address private _strategy;

    constructor (address _token, address _controller) public ERC20(
        string(abi.encodePacked("con ", ERC20(_token).name())),
        string(abi.encodePacked("c", ERC20(_token).symbol()))
    ) Operatable(){
        _underlying = _token;
        controller = _controller;
    }

    function balance() public view returns (uint) {
        return getBalance().add(IStrategy(_strategy).underlyingBalance());
    }

    function setMin(uint _min) external onlyOperator {
        min = _min;
    }

    function setController(address _controller) public onlyOperator {
        controller = _controller;
    }

    // Custom logic in here for how much the vault allows to be borrowed
    // Sets minimum required on-hand to keep small withdrawals cheap
    function available() public view returns (uint) {
        return getBalance().mul(min).div(max);
    }

    function earn() public {
        require(IController(controller).check(msg.sender), "address is ban");
        uint _bal = available();
        IERC20(_underlying).transfer(_strategy, _bal);
        IStrategy(_strategy).invest();

    }

    function stakeAll() external {
        stake(IERC20(_underlying).balanceOf(msg.sender));
    }

    function stake(uint _amount) public override {
        require(IController(controller).check(msg.sender), "address is ban");
        require(_amount > 0, "amount must greater than 0");
        uint _pool = balance();
        uint _before = getBalance();
        doTransferIn(msg.sender, _amount);
        uint _after = getBalance();
        _amount = _after.sub(_before);
        // getPricePerFullShare
        uint shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
    }

    function exit() external override {
        withdraw(balanceOf(msg.sender));
    }

    // Someone might type the wrong coin into the contract, and the operator would take it out
    function salvageToken(address reserve, uint amount) external onlyOperator {
        require(reserve != address(_underlying), "no underlying");
        IERC20(reserve).transfer(operator, amount);
    }

    function withdraw(uint _shares) public nonReentrant override {
        uint r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);
        uint b = getBalance();
        if (b < r) {
            uint _withdraw = r.sub(b);
            IStrategy(_strategy).withdrawToVault(_withdraw);
            uint _after = getBalance();
            uint _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }

        uint256 _fee = r.mul(withdrawalFee).div(withdrawalMax);
        TransferHelper.safeTransfer(_underlying, IController(controller).feeManager(), _fee);
        doTransferOut(msg.sender, r.sub(_fee));
    }

    function setWithdrawFee(uint256 _withdrawalFee) external onlyOperator {
        require(_withdrawalFee < withdrawalMax.div(100), "inappropriate withdraw fee");
        withdrawalFee = _withdrawalFee;
    }

    function getPricePerFullShare() public override view returns (uint) {
        return balance().mul(1e18).div(totalSupply()).div(1e18);
    }

    function setStrategy(address _address) external override {
        require(msg.sender == controller || msg.sender == operator, "controller or Operatable");
        require(_address != address(0), "new _strategy cannot be empty");
        require(
            IStrategy(_address).underlying() == address(_underlying),
            "Vault underlying must match Strategy underlying"
        );
        require(IStrategy(_address).vault() == address(this), "the strategy does not belong to this vault");

        if (_address != _strategy) {
            if (_strategy != address(0)) {// if the original strategy (no underscore) is defined
                TransferHelper.safeApprove(_underlying, _strategy, 0);
                IStrategy(_strategy).withdrawToVault(IERC20(_underlying).balanceOf(_strategy));
            }
            _strategy = _address;
            TransferHelper.safeApprove(_underlying, _strategy, 0);
            TransferHelper.safeApprove(_underlying, _strategy, uint256(~0));
        }
    }

    function underlying() public override view returns (address){
        return _underlying;
    }

    function strategy() public override view returns (address){
        return _strategy;
    }

    function getBalance() internal virtual view returns (uint);

    function doTransferIn(address from, uint amount) internal virtual returns (uint);

    function doTransferOut(address to, uint amount) internal virtual;
}
