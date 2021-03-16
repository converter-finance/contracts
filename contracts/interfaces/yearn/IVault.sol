// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

interface IVault {

    function stake(uint) external;

    function exit() external;

    function withdraw(uint) external;

    function getPricePerFullShare() external view returns (uint);

    function underlying() external view returns (address);

    function strategy() external view returns (address);

    function setStrategy(address) external;

}
