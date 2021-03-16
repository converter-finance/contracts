// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

interface IRewardPool {
    function notifyRewardAmount(uint256 reward) external;

    function setPoolId(uint256 pid) external;
}