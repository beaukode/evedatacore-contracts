// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { Characters, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { TribesTable, TribesTableData } from "../codegen/tables/TribesTable.sol";
import { TribesTickers } from "../codegen/tables/TribesTickers.sol";
import { TribesSystemErrors } from "./TribesSystemErrors.sol";

contract TribesSystem is System {
  modifier onlyWarlord(uint256 tribeId) {
    uint256 callerId = CharactersByAccount.getSmartObjectId(_msgSender());
    uint256 warlordId = TribesTable.getWarlord(tribeId);
    if (callerId != warlordId) {
      revert TribesSystemErrors.TribesSystem_Unauthorized(tribeId, callerId);
    }
    _;
  }

  function claim(uint256 tribeId, bytes8 ticker, string calldata name) public {
    uint256 characterId = CharactersByAccount.getSmartObjectId(_msgSender());

    // Check if the character is member of the tribe
    if (Characters.getTribeId(characterId) != tribeId) {
      revert TribesSystemErrors.TribesSystem_NotMemberOfTribe(tribeId, characterId);
    }

    // Check if the corp is already claimed
    if (isClaimValid(tribeId)) {
      revert TribesSystemErrors.TribesSystem_TribeAlreadyClaimed(tribeId);
    }

    _assertTickerFormat(ticker);
    _assertStringLength(name, 1, 50);

    // Check if ticker is already taken by another corp
    uint256 existingTribeId = TribesTickers.getTribeId(ticker);
    if (existingTribeId != tribeId && existingTribeId != 0) {
      revert TribesSystemErrors.TribesSystem_TickerAlreadyTaken(ticker);
    }

    TribesTickers.set(ticker, tribeId);
    TribesTable.set(tribeId, characterId, ticker, block.timestamp, name, "", "");
  }

  function transfer(uint256 tribeId, uint256 toWarlordId) public onlyWarlord(tribeId) {
    // Check if the new warlord is member of the tribe
    if (Characters.getTribeId(toWarlordId) != tribeId) {
      revert TribesSystemErrors.TribesSystem_NotMemberOfTribe(tribeId, toWarlordId);
    }

    uint256 currentWarlordId = TribesTable.getWarlord(tribeId);
    // Check if the new warlord is the current warlord
    if (currentWarlordId == toWarlordId) {
      revert TribesSystemErrors.TribesSystem_IsAlreadyWarlord(tribeId, currentWarlordId);
    }

    TribesTable.setWarlord(tribeId, toWarlordId);
  }

  function isClaimValid(uint256 tribeId) public view returns (bool) {
    uint256 warlordId = TribesTable.getWarlord(tribeId);

    // Tribe not claimed
    if (warlordId == 0) {
      return false;
    }

    // Tribe claimed, but the warlord is not member of the tribe anymore
    if (Characters.getTribeId(warlordId) != tribeId) {
      return false;
    }

    // Tribe claimed, and the warlord is still member of the tribe
    return true;
  }

  function setMetadata(
    uint256 tribeId,
    string calldata name,
    string calldata description,
    string calldata homepage
  ) public onlyWarlord(tribeId) {
    _assertStringLength(name, 1, 50);
    _assertStringLength(description, 0, 4000);
    _assertStringLength(homepage, 0, 255);

    TribesTable.setName(tribeId, name);
    TribesTable.setDescription(tribeId, description);
    TribesTable.setHomepage(tribeId, homepage);
  }

  function getMetadata(uint256 tribeId) public view returns (TribesTableData memory data) {
    data = TribesTable.get(tribeId);
  }

  function _assertStringLength(string calldata str, uint16 minLength, uint16 maxLength) internal pure {
    uint256 length = bytes(str).length;
    if (length < minLength || length > maxLength) {
      revert TribesSystemErrors.TribesSystem_InvalidStringLength(str, minLength, maxLength);
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
      revert TribesSystemErrors.TribesSystem_InvalidTickerFormat(ticker);
    }

    // Check each character
    for (uint256 i = 0; i < length; i++) {
      bytes1 char = ticker[i];
      bool isCapitalLetter = (char >= 0x41 && char <= 0x5A); // A-Z
      bool isDigit = (char >= 0x30 && char <= 0x39); // 0-9

      if (!isCapitalLetter && !isDigit) {
        revert TribesSystemErrors.TribesSystem_InvalidTickerFormat(ticker);
      }
    }
  }
}
