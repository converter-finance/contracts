// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

interface IRewards {
    function withdraw(uint) external;
    function getReward() external;
    function stake(uint) external;
    function balanceOf(address) external view returns (uint);
    function exit() external;
}
