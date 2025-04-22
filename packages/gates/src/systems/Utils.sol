// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { GATE_ACCESS_SYSTEM_NAME, GATE_CONFIG_SYSTEM_NAME } from "./constants.sol";

library Utils {
  function gatesAccessSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: GATE_ACCESS_SYSTEM_NAME });
  }

  function gatesConfigSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: GATE_CONFIG_SYSTEM_NAME });
  }
}
