// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { CharactersTable } from "@eveworld/world/src/codegen/tables/CharactersTable.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";
import { CorporationsTable } from "../codegen/tables/CorporationsTable.sol";
import { CorporationsSystemErrors } from "./CorporationsSystemErrors.sol";

contract CorporationsSystem is System {
  function claim(uint256 corpId, bytes8 ticker, string calldata name) public {
    uint256 characterId = CharactersByAddressTable.getCharacterId(_msgSender());

    // Check if the character is member of the corp
    if (CharactersTable.getCorpId(characterId) != corpId) {
      revert CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp(corpId);
    }

    // Check if the corp is already claimed
    if (_isClaimValid(corpId)) {
      revert CorporationsSystemErrors.CorporationsSystem_CorpAlreadyClaimed(corpId);
    }

    CorporationsTable.set(corpId, characterId, ticker, block.timestamp, name, "", "");
  }

  function _isClaimValid(uint256 corpId) internal view returns (bool) {
    uint256 ceoId = CorporationsTable.getCEO(corpId);

    // Corp not claimed
    if (ceoId == 0) {
      return false;
    }

    // Corp claimed, but the CEO is not member of the corp anymore
    if (CharactersTable.getCorpId(ceoId) != corpId) {
      return false;
    }

    return true;
  }
}
