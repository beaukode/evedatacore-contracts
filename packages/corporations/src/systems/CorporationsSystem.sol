// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { CharactersTable } from "@eveworld/world/src/codegen/tables/CharactersTable.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";
import { CorporationsTable } from "../codegen/tables/CorporationsTable.sol";
import { CorporationsSystemErrors } from "./CorporationsSystemErrors.sol";

contract CorporationsSystem is System {
  modifier onlyCEO(uint256 corpId) {
    uint256 callerId = CharactersByAddressTable.getCharacterId(_msgSender());
    uint256 ceoId = CorporationsTable.getCEO(corpId);
    if (callerId != ceoId) {
      revert CorporationsSystemErrors.CorporationsSystem_Unauthorized(corpId, callerId);
    }
    _;
  }

  function claim(uint256 corpId, bytes8 ticker, string calldata name) public {
    uint256 characterId = CharactersByAddressTable.getCharacterId(_msgSender());

    // Check if the character is member of the corp
    if (CharactersTable.getCorpId(characterId) != corpId) {
      revert CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp(corpId, characterId);
    }

    // Check if the corp is already claimed
    if (_isClaimValid(corpId)) {
      revert CorporationsSystemErrors.CorporationsSystem_CorpAlreadyClaimed(corpId);
    }

    _assertTickerFormat(ticker);
    _assertStringLength(name, 1, 50);
    CorporationsTable.set(corpId, characterId, ticker, block.timestamp, name, "", "");
  }

  function transfer(uint256 corpId, uint256 toCeoId) public onlyCEO(corpId) {
    // Check if the new CEO is member of the corp
    if (CharactersTable.getCorpId(toCeoId) != corpId) {
      revert CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp(corpId, toCeoId);
    }

    uint256 currentCeoId = CorporationsTable.getCEO(corpId);
    // Check if the new CEO is the current CEO
    if (currentCeoId == toCeoId) {
      revert CorporationsSystemErrors.CorporationsSystem_IsAlreadyCeo(corpId, currentCeoId);
    }

    CorporationsTable.setCEO(corpId, toCeoId);
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

    // Corp claimed, and the CEO is still member of the corp
    return true;
  }

  function _assertStringLength(string calldata str, uint8 minLength, uint8 maxLength) internal pure {
    uint256 length = bytes(str).length;
    if (length < minLength || length > maxLength) {
      revert CorporationsSystemErrors.CorporationsSystem_InvalidStringLength(str, minLength, maxLength);
    }
  }

  function _assertTickerFormat(bytes8 ticker) internal pure {    
    uint256 length = 0;
    
    // Count actual length (until first zero byte)
    for (uint256 i = 0; i < 8; i++) {
      if (ticker[i] == 0) {
        break;
      }
      length++;
    }

    // Check length
    if (length < 1 || length > 5) {
      revert CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat(ticker);
    }

    // Check each character
    for (uint256 i = 0; i < length; i++) {
      bytes1 char = ticker[i];
      bool isCapitalLetter = (char >= 0x41 && char <= 0x5A); // A-Z
      bool isDigit = (char >= 0x30 && char <= 0x39); // 0-9
      
      if (!isCapitalLetter && !isDigit) {
        revert CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat(ticker);
      }
    }
  }
}
