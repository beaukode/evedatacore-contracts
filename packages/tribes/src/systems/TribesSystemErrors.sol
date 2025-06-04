// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

interface TribesSystemErrors {
  error TribesSystem_NotMemberOfTribe(uint256 tribeId, uint256 warlordId);
  error TribesSystem_NotWarlordOfTribe();
  error TribesSystem_TribeAlreadyClaimed(uint256 tribeId);
  error TribesSystem_TribeNotClaimed();
  error TribesSystem_IsAlreadyWarlord(uint256 tribeId, uint256 warlordId);
  error TribesSystem_Unauthorized(uint256 tribeId, uint256 callerId);
  error TribesSystem_InvalidStringLength(string value, uint16 minLength, uint16 maxLength);
  error TribesSystem_InvalidTickerFormat(bytes8 ticker);
  error TribesSystem_TickerAlreadyTaken(bytes8 ticker);
}
