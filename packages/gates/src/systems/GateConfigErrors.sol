// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

interface GateConfigErrors {
  error GateConfig_Unauthorized(address caller, address gateOwner);
}
