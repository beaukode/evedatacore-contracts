// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

interface CorporationsSystemErrors {
  error CorporationsSystem_NotMemberOfCorp(uint256 corpId, uint256 ceoId);
  error CorporationsSystem_NotCEOOfCorp();
  error CorporationsSystem_CorpAlreadyClaimed(uint256 corpId);
  error CorporationsSystem_CorpNotClaimed();
  error CorporationsSystem_IsAlreadyCeo(uint256 corpId, uint256 ceoId);
  error CorporationsSystem_Unauthorized(uint256 corpId, uint256 callerId);
  error CorporationsSystem_InvalidStringLength(string value, uint16 minLength, uint16 maxLength);
  error CorporationsSystem_InvalidTickerFormat(bytes8 ticker);
  error CorporationsSystem_TickerAlreadyTaken(bytes8 ticker);
}
