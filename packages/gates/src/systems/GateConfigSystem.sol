// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { DeployableTokenTable } from "@eveworld/world/src/codegen/tables/DeployableTokenTable.sol";
import { IERC721 } from "@eveworld/world/src/modules/eve-erc721-puppet/IERC721.sol";
import { Gates } from "../codegen/tables/Gates.sol";
import { GatesCharacterExceptions } from "../codegen/tables/GatesCharacterExceptions.sol";
import { GatesCorpExceptions } from "../codegen/tables/GatesCorpExceptions.sol";
import { GateConfigErrors } from "./GateConfigErrors.sol";

contract GateConfigSystem is System {
  function _getOwner(uint256 gateId) internal returns (address owner) {
    owner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(gateId);
  }

  modifier onlyOwner(uint256 gateId) {
    address gateOwner = _getOwner(gateId);
    if (_msgSender() != gateOwner) {
      revert GateConfigErrors.GateConfig_Unauthorized(_msgSender(), gateOwner);
    }
    _;
  }

  function setDefaultRule(uint256 gateId, bool allow) public onlyOwner(gateId) {
    uint256 createdAt = Gates.getCreatedAt(gateId);
    if (createdAt == 0) {
      // First time registration
      Gates.set(gateId, allow, block.timestamp);
    } else {
      Gates.setDefaultRule(gateId, allow);
    }
  }

  function addCharacterException(uint256 gateId, uint256 characterId) public onlyOwner(gateId) {
    GatesCharacterExceptions.set(gateId, characterId, true);
  }

  function removeCharacterException(uint256 gateId, uint256 characterId) public onlyOwner(gateId) {
    GatesCharacterExceptions.set(gateId, characterId, false);
  }

  function addCorpException(uint256 gateId, uint256 corpId) public onlyOwner(gateId) {
    GatesCorpExceptions.set(gateId, corpId, true);
  }

  function removeCorpException(uint256 gateId, uint256 corpId) public onlyOwner(gateId) {
    GatesCorpExceptions.set(gateId, corpId, false);
  }
}
