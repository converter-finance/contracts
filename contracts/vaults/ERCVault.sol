// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "./Vault.sol";

contract ERCVault is Vault {
    constructor (address _token, address _controller) public Vault(_token, _controller){

    }
    function getBalance() internal override view returns (uint){
        return IERC20(underlying()).balanceOf(address(this));
    }


    function doTransferIn(address from, uint amount) internal override returns (uint) {
        uint balanceBefore = IERC20(underlying()).balanceOf(address(this));
        TransferHelper.safeTransferFrom(underlying(), from, address(this), amount);

        uint balanceAfter = IERC20(underlying()).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore;

    }


    function doTransferOut(address to, uint amount) internal override {
        TransferHelper.safeTransfer(underlying(), to, amount);
    }
}