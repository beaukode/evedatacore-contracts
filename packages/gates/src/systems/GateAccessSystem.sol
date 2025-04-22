// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { CharactersTable } from "@eveworld/world/src/codegen/tables/CharactersTable.sol";
import { Gates, GatesData } from "../codegen/tables/Gates.sol";
import { GatesCorpExceptions } from "../codegen/tables/GatesCorpExceptions.sol";
import { GatesCharacterExceptions } from "../codegen/tables/GatesCharacterExceptions.sol";

contract GateAccessSystem is System {
  function canJump(uint256 characterId, uint256 sourceGateId, uint256) public view returns (bool) {
    uint256 corpId = CharactersTable.getCorpId(characterId);
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
