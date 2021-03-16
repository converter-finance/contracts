// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;


interface IStrategy {

    function underlying() external view returns (address);

    function underlyingBalance() external view returns (uint);

    function vault() external view returns (address);

    function invest() external;

    function harvest() external;

    function withdrawToVault(uint) external;

    function withdrawAllToVault() external;

    function salvageToken(address) external returns (uint balance);


}
