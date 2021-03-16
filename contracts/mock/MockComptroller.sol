// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

contract MockComptroller {
  constructor() public {
  }

  function enterMarkets(address[] memory ctokens) public pure returns(uint[] memory){
    ctokens;
    return new uint[](1);
  }

  function markets(address ctoken) public pure returns (bool, uint256) {
    // got from compound for cusdc
    ctoken;
    return (true, 750000000000000000);
  }

  function compSpeeds(address ctoken) external pure returns (uint256) {
    // got from compound for cusdc
    ctoken;
    return 13416296358152430;
  }

  function claimComp(address recipient) external {}

  function claimComp(address holder, address[] memory cTokens) external{
  }
  function getAllMarkets() external view returns (address[] memory) {
  }
}
