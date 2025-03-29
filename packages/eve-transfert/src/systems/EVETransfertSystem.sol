// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { IERC20 } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20.sol";

contract EVETransfertSystem is System {
  IERC20 public token = IERC20(0xCDA7a1148bc27A4dBA8623324116a835207D435E);

  function getBalance() public view returns (uint256 balance) {
    return token.balanceOf(_msgSender());
  }

  function getAllowance() public view returns (uint256 allowance) {
    return token.allowance(_msgSender(), address(this));
  }

  function transferTokens(address recipient, uint256 amount) public returns (bool success) {
    require(recipient != address(0), "Cannot transfer to zero address");
    require(amount > 0, "Transfer amount must be greater than 0");
    require(token.balanceOf(_msgSender()) >= amount, "Insufficient balance");

    // bool result = token.transfer(recipient, amount);
    bool result = token.transferFrom(_msgSender(), recipient, amount);

    return result;
  }
}
