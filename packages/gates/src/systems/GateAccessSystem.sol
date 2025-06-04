// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { Characters } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/Characters.sol";
import { EntityRecordMetadata } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/EntityRecordMetadata.sol";
import { GatesDapp } from "../codegen/tables/GatesDapp.sol";
import { Gates, GatesData } from "../codegen/tables/Gates.sol";
import { GatesCorpExceptions } from "../codegen/tables/GatesCorpExceptions.sol";
import { GatesCharacterExceptions } from "../codegen/tables/GatesCharacterExceptions.sol";

contract GateAccessSystem is System {
  function canJump(uint256 characterId, uint256 sourceGateId, uint256) public view returns (bool) {
    string memory gateDappURL = EntityRecordMetadata.getDappURL(sourceGateId);
    string memory expectedDappURL = GatesDapp.getDappUrl();
    if (keccak256(bytes(gateDappURL)) != keccak256(bytes(expectedDappURL))) {
      return true; // Disable filtering if the url is not correct
    }

    uint256 corpId = Characters.getTribeId(characterId);
    if (corpId == 0) {
      return false; // Character do not exists
    }

    GatesData memory gate = Gates.get(sourceGateId);
    if (gate.createdAt == 0) {
      return false; // Gate is not registered
    }

    if (GatesCorpExceptions.get(sourceGateId, corpId)) {
      return !gate.defaultRule;
    }

    if (GatesCharacterExceptions.get(sourceGateId, characterId)) {
      return !gate.defaultRule;
    }

    return gate.defaultRule;
  }
}
