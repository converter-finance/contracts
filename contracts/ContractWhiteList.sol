// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "./Operatable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ContractWhiteList is Operatable {
    using Address for address;

    mapping(address => bool) public contractWhiteList;

    constructor() Operatable() public {
    }
    function addContract(address _target) onlyOperator public {
        contractWhiteList[_target] = true;
    }

    function removeContract(address _target) onlyOperator public {
        contractWhiteList[_target] = false;
    }

    // File: @openzeppelin/contracts/utils/Address.sol
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }


}