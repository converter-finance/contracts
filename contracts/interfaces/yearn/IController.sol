// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

interface IController {

    function underlying(address) external view returns (address);

    function feeManager() external view returns (address);

    function check(address _target) external view returns (bool);
}
