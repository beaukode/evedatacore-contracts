// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

interface SSUSystemErrors {
  error SSUSystem_Unauthorized(address caller, uint256 callerTribe, address ssuOwner, uint256 ssuOwnerTribe);
  error SSUSystem_UnauthorizedRecipient(address caller, address to);
  error SSUSystem_CannotTransferToOwner(address caller, address to);
}
