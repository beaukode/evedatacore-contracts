// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import {
  smartCharacterSystem
} from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import {
  smartStorageUnitSystem
} from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import {
  deployableSystem
} from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { inventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import {
  ephemeralInteractSystem
} from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { CreateInventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";
import {
  Tenant,
  CharactersByAccount,
  Characters,
  EntityRecordMetadata,
  LocationData,
  Inventory,
  InventoryItem,
  EphemeralInvItem
} from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import {
  EntityRecordParams,
  EntityMetadataParams
} from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { InventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";

import { SSUSystem } from "../src/systems/SSUSystem.sol";
import { SSUSystemErrors } from "../src/systems/SSUSystemErrors.sol";

import { Utils } from "../src/systems/Utils.sol";

contract SSUTest is MudTest {
  using WorldResourceIdInstance for ResourceId;
  IWorldWithContext private world;

  uint256 private smartCharacterTypeId;
  uint256 private smartStorageUnitTypeId;
  bytes32 private tenantId;

  mapping(string => uint256) private corps;
  mapping(string => uint256) private characters;

  uint256 private deployerPrivateKey;
  address private admin;
  address private player1;
  address private player2;
  address private player3;
  address private player4;
  uint256 private smartObjectId;
  uint256 private smartObjectId2; // Second SSU without access set
  uint256 private nonSingletonObjectId;

  ResourceId private systemId;

  //Setup for the tests
  function setUp() public override {
    vm.pauseGasMetering();
    super.setUp();
    world = IWorldWithContext(worldAddress);

    smartCharacterTypeId = vm.envUint("CHARACTER_TYPE_ID");
    smartStorageUnitTypeId = vm.envUint("SSU_TYPE_ID");

    tenantId = Tenant.get();

    // Initialize corps mapping
    corps["corp1"] = 70000001;
    corps["corp2"] = 70000002;

    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    admin = vm.addr(deployerPrivateKey);
    player1 = vm.addr(vm.envUint("PLAYER1_PRIVATE_KEY"));
    player2 = vm.addr(vm.envUint("PLAYER2_PRIVATE_KEY"));
    player3 = vm.addr(vm.envUint("PLAYER3_PRIVATE_KEY"));

    // Convert string to bytes14 using abi.encodePacked
    bytes14 namespace = bytes14(abi.encodePacked(vm.envOr("SSU_NAMESPACE", vm.envString("DEFAULT_NAMESPACE"))));
    systemId = Utils.ssuSystemId(namespace);

    vm.startBroadcast(deployerPrivateKey);

    characters["player1"] = _calculateObjectId(smartCharacterTypeId, 71, true);
    characters["player2"] = _calculateObjectId(smartCharacterTypeId, 72, true);
    characters["player3"] = _calculateObjectId(smartCharacterTypeId, 73, true);
    characters["player4"] = _calculateObjectId(smartCharacterTypeId, 74, true);

    if (CharactersByAccount.get(admin) == 0) {
      smartCharacterSystem.createCharacter(
        _calculateObjectId(smartCharacterTypeId, 42, true),
        admin,
        corps["corp1"],
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 42, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "beauKode", dappURL: "https://evedataco.re", description: "EVE Datacore website" })
      );
    }
    if (CharactersByAccount.get(player1) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player1"],
        player1,
        corps["corp1"],
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 71, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player1", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player2) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player2"],
        player2,
        corps["corp1"],
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 72, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player2", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player3) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player3"],
        player3,
        corps["corp2"],
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 73, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player3", dappURL: "", description: "" })
      );
    }

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartStorageUnitTypeId,
      itemId: 1234,
      volume: 1000
    });
    smartObjectId = _calculateObjectId(smartStorageUnitTypeId, entityRecordParams.itemId, true);
    smartStorageUnitSystem.createAndAnchorStorageUnit(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        player1,
        LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 })
      ),
      1000,
      1000,
      0
    );

    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](1);
    nonSingletonObjectId = _calculateObjectId(9090, 0, false);
    items[0] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: 9090,
      itemId: 0,
      quantity: 9,
      volume: 100
    });

    vm.stopBroadcast();

    vm.startPrank(player1, admin);
    deployableSystem.bringOnline(smartObjectId);
    inventorySystem.createAndDepositInventory(smartObjectId, items);
    vm.stopPrank();

    vm.startPrank(player1);
    // SSU Owner can set the access to the SSU contract
    address ssuContractAddress = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.getContractAddress, ())),
      (address)
    );
    ephemeralInteractSystem.setTransferToEphemeralAccess(smartObjectId, ssuContractAddress, true);
    vm.stopPrank();

    // Create a second SSU without access set (for testing isSystemAllowed)
    EntityRecordParams memory entityRecordParams2 = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartStorageUnitTypeId,
      itemId: 5678,
      volume: 1000
    });
    smartObjectId2 = _calculateObjectId(smartStorageUnitTypeId, entityRecordParams2.itemId, true);

    vm.startPrank(player1, admin);
    smartStorageUnitSystem.createAndAnchorStorageUnit(
      CreateAndAnchorParams(
        smartObjectId2,
        "SSU2",
        entityRecordParams2,
        player1,
        LocationData({ solarSystemId: 1, x: 2002, y: 2002, z: 2002 })
      ),
      1000,
      1000,
      0
    );
    deployableSystem.bringOnline(smartObjectId2);
    vm.stopPrank();
  }

  function testSameTribeTransferToSelf() public {
    vm.startPrank(player2);
    InventoryItemParams[] memory items = new InventoryItemParams[](1);
    items[0] = InventoryItemParams({ smartObjectId: nonSingletonObjectId, quantity: 1 });

    // Check initial state: main inventory has 9 items, ephemeral inventory is empty
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 9);
    assertFalse(EphemeralInvItem.getExists(smartObjectId, player2, nonSingletonObjectId));

    world.call(systemId, abi.encodeCall(SSUSystem.transferToEphemeral, (smartObjectId, player2, items)));

    // Check after transfer: main inventory has 8 items (9 - 1), ephemeral inventory has 1
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 8);
    assertTrue(EphemeralInvItem.getExists(smartObjectId, player2, nonSingletonObjectId));
    assertEq(EphemeralInvItem.getQuantity(smartObjectId, player2, nonSingletonObjectId), 1);
    vm.stopPrank();
  }

  // Test onlyOwnerTribeMember modifier - should revert when caller is from different tribe
  function testDifferentTribeCannotTransfer() public {
    vm.startPrank(player3);
    InventoryItemParams[] memory items = new InventoryItemParams[](1);
    items[0] = InventoryItemParams({ smartObjectId: nonSingletonObjectId, quantity: 1 });

    // Check initial state: main inventory has 9 items, ephemeral inventory is empty
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 9);
    assertFalse(EphemeralInvItem.getExists(smartObjectId, player3, nonSingletonObjectId));

    // Get actual tribe IDs
    uint256 player3Tribe = Characters.getTribeId(characters["player3"]);
    uint256 player1Tribe = Characters.getTribeId(characters["player1"]);

    // player3 is in corp2, but SSU owner (player1) is in corp1
    vm.expectRevert(
      abi.encodeWithSelector(
        SSUSystemErrors.SSUSystem_Unauthorized.selector,
        player3,
        player3Tribe, // player3's tribe
        player1, // SSU owner
        player1Tribe // SSU owner's tribe
      )
    );
    world.call(systemId, abi.encodeCall(SSUSystem.transferToEphemeral, (smartObjectId, player3, items)));

    // Verify nothing changed after revert: main inventory still has 9 items, ephemeral inventory still empty
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 9);
    assertFalse(EphemeralInvItem.getExists(smartObjectId, player3, nonSingletonObjectId));
    vm.stopPrank();
  }

  // Test onlyToCaller modifier - should revert when trying to transfer to someone else
  function testCannotTransferToOtherAddress() public {
    vm.startPrank(player2);
    InventoryItemParams[] memory items = new InventoryItemParams[](1);
    items[0] = InventoryItemParams({ smartObjectId: nonSingletonObjectId, quantity: 1 });

    // Check initial state: main inventory has 9 items, ephemeral inventory is empty
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 9);
    assertFalse(EphemeralInvItem.getExists(smartObjectId, player3, nonSingletonObjectId));

    // player2 trying to transfer to player3 (not themselves)
    vm.expectRevert(
      abi.encodeWithSelector(
        SSUSystemErrors.SSUSystem_UnauthorizedRecipient.selector,
        player2, // caller
        player3 // recipient (not the caller)
      )
    );
    world.call(systemId, abi.encodeCall(SSUSystem.transferToEphemeral, (smartObjectId, player3, items)));

    // Verify nothing changed after revert: main inventory still has 9 items, ephemeral inventory still empty
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 9);
    assertFalse(EphemeralInvItem.getExists(smartObjectId, player3, nonSingletonObjectId));
    vm.stopPrank();
  }

  // Test notToOwner modifier - should revert when owner tries to transfer to themselves
  function testCannotTransferToOwner() public {
    vm.startPrank(player1);
    InventoryItemParams[] memory items = new InventoryItemParams[](1);
    items[0] = InventoryItemParams({ smartObjectId: nonSingletonObjectId, quantity: 1 });

    // Check initial state: main inventory has 9 items, ephemeral inventory is empty
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 9);
    assertFalse(EphemeralInvItem.getExists(smartObjectId, player1, nonSingletonObjectId));

    // player1 (the SSU owner) trying to transfer to themselves
    // This passes onlyOwnerTribeMember and onlyToCaller, but fails notToOwner
    vm.expectRevert(
      abi.encodeWithSelector(
        SSUSystemErrors.SSUSystem_CannotTransferToOwner.selector,
        player1, // owner (to address)
        player1 // owner (same as to)
      )
    );
    world.call(systemId, abi.encodeCall(SSUSystem.transferToEphemeral, (smartObjectId, player1, items)));

    // Verify nothing changed after revert: main inventory still has 9 items, ephemeral inventory still empty
    assertEq(InventoryItem.getQuantity(smartObjectId, nonSingletonObjectId), 9);
    assertFalse(EphemeralInvItem.getExists(smartObjectId, player1, nonSingletonObjectId));
    vm.stopPrank();
  }

  // Test getContractAddress view function
  function testGetContractAddress() public {
    // Call getContractAddress through the world
    address contractAddress = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.getContractAddress, ())),
      (address)
    );

    // Verify it returns a non-zero address
    assertNotEq(contractAddress, address(0), "Contract address should not be zero");

    // Verify it returns the same address on multiple calls (consistency)
    address contractAddress2 = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.getContractAddress, ())),
      (address)
    );
    assertEq(contractAddress, contractAddress2, "Contract address should be consistent");
  }

  // Test isSystemAllowed view function - should return true when access is set
  function testIsSystemAllowedWhenAccessIsSet() public {
    // In setUp, access is already set for smartObjectId
    // Call isSystemAllowed through the world to verify it returns true
    bool isAllowed = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.isSystemAllowed, (smartObjectId))),
      (bool)
    );

    // Verify it returns true since access was set in setUp
    assertTrue(isAllowed, "System should be allowed when access is set");
  }

  // Test isSystemAllowed view function - should return false when access is not set
  function testIsSystemAllowedWhenAccessIsNotSet() public {
    // Use smartObjectId2 from setUp (SSU without access set)
    // Call isSystemAllowed for the SSU (access not set)
    bool isAllowed = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.isSystemAllowed, (smartObjectId2))),
      (bool)
    );

    // Verify it returns false since access was not set
    assertFalse(isAllowed, "System should not be allowed when access is not set");
  }

  // Test isSystemAllowed view function - should return false when access is removed
  function testIsSystemAllowedWhenAccessIsRemoved() public {
    // First verify access is set (from setUp)
    bool isAllowedBefore = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.isSystemAllowed, (smartObjectId))),
      (bool)
    );
    assertTrue(isAllowedBefore, "System should be allowed initially");

    // Remove access
    vm.startPrank(player1);
    address ssuContractAddress = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.getContractAddress, ())),
      (address)
    );
    ephemeralInteractSystem.setTransferToEphemeralAccess(smartObjectId, ssuContractAddress, false);
    vm.stopPrank();

    // Call isSystemAllowed after removing access
    bool isAllowedAfter = abi.decode(
      world.call(systemId, abi.encodeCall(SSUSystem.isSystemAllowed, (smartObjectId))),
      (bool)
    );

    // Verify it returns false after removing access
    assertFalse(isAllowedAfter, "System should not be allowed after access is removed");
  }

  function _calculateObjectId(uint256 typeId, uint256 itemId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of typeId
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
}
