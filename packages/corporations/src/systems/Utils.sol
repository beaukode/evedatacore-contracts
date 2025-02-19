// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { CORPORATIONS_DEPLOYMENT_NAMESPACE, CORPORATIONS_SYSTEM_NAME } from "./constants.sol";

library Utils {
  function corporationsSystemId() internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: CORPORATIONS_DEPLOYMENT_NAMESPACE,
        name: CORPORATIONS_SYSTEM_NAME
      });
  }
}
