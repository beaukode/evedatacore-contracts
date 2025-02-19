// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

interface CorporationsSystemErrors {
  error CorporationsSystem_NotMemberOfCorp(uint256 corpId);
  error CorporationsSystem_NotCEOOfCorp();
  error CorporationsSystem_CorpAlreadyClaimed(uint256 corpId);
  error CorporationsSystem_CorpNotClaimed();
}
