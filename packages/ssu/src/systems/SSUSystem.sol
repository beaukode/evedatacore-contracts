// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import {
  ephemeralInteractSystem
} from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { InventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";
import {
  OwnershipByObject,
  CharactersByAccount,
  Characters
} from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { HasRole, Role } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

import { SSUSystemErrors } from "./SSUSystemErrors.sol";

contract SSUSystem is System {
  function _getOwner(uint256 ssuId) internal view returns (address owner) {
    owner = OwnershipByObject.get(ssuId);
  }

  function _getAccountTribe(address account) internal view returns (uint256 tribeId) {
    uint256 characterId = CharactersByAccount.getSmartObjectId(account);
    tribeId = Characters.getTribeId(characterId);
  }

  modifier onlyOwnerTribeMember(uint256 ssuId) {
    address ssuOwner = _getOwner(ssuId);
    uint256 ssuOwnerTribe = _getAccountTribe(ssuOwner);
    address sender = _msgSender();
    uint256 senderTribe = _getAccountTribe(sender);
    if (ssuOwnerTribe != senderTribe) {
      revert SSUSystemErrors.SSUSystem_Unauthorized(sender, senderTribe, ssuOwner, ssuOwnerTribe);
    }
    _;
  }

  modifier onlyToCaller(address to) {
    address sender = _msgSender();
    if (to != sender) {
      revert SSUSystemErrors.SSUSystem_UnauthorizedRecipient(sender, to);
    }
    _;
  }

  modifier notToOwner(uint256 ssuId, address to) {
    address ssuOwner = _getOwner(ssuId);
    if (to == ssuOwner) {
      revert SSUSystemErrors.SSUSystem_CannotTransferToOwner(to, to);
    }
    _;
  }

  function transferToEphemeral(
    uint256 ssuId,
    address to,
    InventoryItemParams[] memory items
  ) public onlyOwnerTribeMember(ssuId) onlyToCaller(to) notToOwner(ssuId, to) {
    ephemeralInteractSystem.transferToEphemeral(ssuId, to, items);
  }

  function getContractAddress() public view returns (address) {
    return address(this);
  }

  function isSystemAllowed(uint256 ssuId) public view returns (bool) {
    bytes32 roleId = keccak256(abi.encodePacked("TRANSFER_TO_EPHEMERAL_ROLE", ssuId));
    if (!Role.getExists(roleId)) {
      return false;
    }
    return HasRole.getIsMember(roleId, address(this));
  }
}
