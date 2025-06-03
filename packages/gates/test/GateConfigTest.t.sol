// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { smartGateSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";

import { Tenant, LocationData, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";

import { Gates, GatesData } from "../src/codegen/tables/Gates.sol";
import { GatesCorpExceptions } from "../src/codegen/tables/GatesCorpExceptions.sol";
import { GatesCharacterExceptions } from "../src/codegen/tables/GatesCharacterExceptions.sol";

import { GateConfigSystem } from "../src/systems/GateConfigSystem.sol";
import { GateConfigErrors } from "../src/systems/GateConfigErrors.sol";
import { Utils } from "../src/systems/Utils.sol";

contract GateConfigTest is MudTest {
  using WorldResourceIdInstance for ResourceId;
  IWorldWithContext private world;

  uint256 private smartCharacterTypeId;
  bytes32 private tenantId;

  uint256 private constant SMART_GATE_TYPE_ID = 84955;

  uint256 private corp1 = 70000001;
  uint256 private corp2 = 70000002;

  address private admin;
  address private player1;
  address private player2;

  uint256 private smartGate1;
  uint256 private smartGate2;

  ResourceId private systemId;

  //Setup for the tests
  function setUp() public override {
    vm.pauseGasMetering();
    super.setUp();
    world = IWorldWithContext(worldAddress);

    smartCharacterTypeId = vm.envUint("CHARACTER_TYPE_ID");

    tenantId = Tenant.get();

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    admin = vm.addr(deployerPrivateKey);
    player1 = vm.addr(vm.envUint("PLAYER1_PRIVATE_KEY"));
    player2 = vm.addr(vm.envUint("PLAYER2_PRIVATE_KEY"));

    // Convert string to bytes14 using abi.encodePacked
    bytes14 namespace = bytes14(abi.encodePacked(vm.envOr("GATES_NAMESPACE", vm.envString("DEFAULT_NAMESPACE"))));
    systemId = Utils.gatesConfigSystemId(namespace);

    vm.startBroadcast(deployerPrivateKey);

    if (CharactersByAccount.get(admin) == 0) {
      smartCharacterSystem.createCharacter(
        _calculateObjectId(smartCharacterTypeId, 42, true),
        admin,
        corp1,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 42, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "beauKode", dappURL: "https://evedataco.re", description: "EVE Datacore website" })
      );
    }
    if (CharactersByAccount.get(player1) == 0) {
      smartCharacterSystem.createCharacter(
        _calculateObjectId(smartCharacterTypeId, 71, true),
        player1,
        corp1,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 71, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player1", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player2) == 0) {
      smartCharacterSystem.createCharacter(
        _calculateObjectId(smartCharacterTypeId, 72, true),
        player2,
        corp2,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 72, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player2", dappURL: "", description: "" })
      );
    }

    smartGate1 = createSmartGate(100);
    smartGate2 = createSmartGate(101);

    vm.stopBroadcast();
  }

  function createSmartGate(uint256 itemId) internal returns (uint256) {
    uint256 smartObjectId = _calculateObjectId(SMART_GATE_TYPE_ID, itemId, true);
    EntityRecordParams memory entityRecordData = EntityRecordParams({
      typeId: SMART_GATE_TYPE_ID,
      itemId: itemId,
      volume: 10000,
      tenantId: tenantId
    });
    LocationData memory worldPosition = LocationData({ solarSystemId: 1, x: 10000, y: 10000, z: 10000 });

    smartGateSystem.createAndAnchorGate(
      CreateAndAnchorParams(smartObjectId, "SG", entityRecordData, player1, worldPosition),
      100000000 * 1e18, // maxDistance
      0 // Network node id
    );

    deployableSystem.bringOnline(smartObjectId);

    return smartObjectId;
  }

  function testInitialRegistrationWithTrueDefaultRule() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (smartGate1, true)));

    // Gate 100 is registered and default rule is true
    GatesData memory gateData = Gates.get(smartGate1);
    assertEq(gateData.createdAt, block.timestamp);
    assertEq(gateData.defaultRule, true);

    // Gate 101 is not registered yet
    gateData = Gates.get(smartGate2);
    assertEq(gateData.createdAt, 0);
    assertEq(gateData.defaultRule, false);

    vm.stopBroadcast();
  }

  function testInitialRegistrationWithFalseDefaultRule() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (smartGate1, false)));

    // Gate 100 is registered and default rule is false
    GatesData memory gateData = Gates.get(smartGate1);
    assertEq(gateData.createdAt, block.timestamp);
    assertEq(gateData.defaultRule, false);

    // Gate 101 is not registered yet
    gateData = Gates.get(smartGate2);
    assertEq(gateData.createdAt, 0);
    assertEq(gateData.defaultRule, false);

    vm.stopBroadcast();
  }

  function testInitialRegistrationRevertIfNotOwner() public {
    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (smartGate1, true)));

    // Gate 100 still not registered
    GatesData memory gateData = Gates.get(smartGate1);
    assertEq(gateData.createdAt, 0);
    assertEq(gateData.defaultRule, false);

    vm.stopBroadcast();
  }

  function testUpdateDefaultRule() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (smartGate1, false)));
    uint256 currentTimestamp = block.timestamp;

    // Gate 100 is registered and default rule is false
    GatesData memory gateData = Gates.get(smartGate1);
    assertEq(gateData.createdAt, currentTimestamp);
    assertEq(gateData.defaultRule, false);

    vm.warp(block.timestamp + 100);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (smartGate1, true)));

    // Gate 100 is registered and default rule is true
    gateData = Gates.get(smartGate1);
    assertEq(gateData.createdAt, currentTimestamp); // createdAt should not be updated
    assertEq(gateData.defaultRule, true);

    vm.stopBroadcast();
  }

  function testUpdateDefaultRuleRevertIfNotOwner() public {
    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (smartGate1, true)));
    assertEq(Gates.getCreatedAt(smartGate1), 0);
    vm.stopBroadcast();
  }

  function testAddCorpException() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCorpException, (smartGate1, corp1)));
    bool corpException = GatesCorpExceptions.get(smartGate1, corp1);
    assertTrue(corpException);
    vm.stopBroadcast();
  }

  function testAddCorpExceptionRevertIfNotOwner() public {
    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCorpException, (smartGate1, corp1)));
    bool corpException = GatesCorpExceptions.get(smartGate1, corp1);
    assertFalse(corpException);
    vm.stopBroadcast();
  }

  function testRemoveCorpException() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCorpException, (smartGate1, corp1)));
    world.call(systemId, abi.encodeCall(GateConfigSystem.removeCorpException, (smartGate1, corp1)));
    bool corpException = GatesCorpExceptions.get(smartGate1, corp1);
    assertFalse(corpException);
    vm.stopBroadcast();
  }

  function testRemoveCorpExceptionRevertIfNotOwner() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCorpException, (smartGate1, corp1)));
    vm.stopBroadcast();

    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.removeCorpException, (smartGate1, corp1)));

    // The record should still be there
    bool corpException = GatesCorpExceptions.get(smartGate1, corp1);
    assertTrue(corpException);
    vm.stopBroadcast();
  }

  function testAddCharacterException() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCharacterException, (smartGate1, 71)));
    bool characterException = GatesCharacterExceptions.get(smartGate1, 71);
    assertTrue(characterException);
    vm.stopBroadcast();
  }

  function testAddCharacterExceptionRevertIfNotOwner() public {
    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCharacterException, (smartGate1, 71)));
    bool characterException = GatesCharacterExceptions.get(smartGate1, 71);
    assertFalse(characterException);
    vm.stopBroadcast();
  }

  function testRemoveCharacterException() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCharacterException, (smartGate1, 71)));
    world.call(systemId, abi.encodeCall(GateConfigSystem.removeCharacterException, (smartGate1, 71)));
    bool characterException = GatesCharacterExceptions.get(smartGate1, 71);
    assertFalse(characterException);
    vm.stopBroadcast();
  }

  function testRemoveCharacterExceptionRevertIfNotOwner() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.addCharacterException, (smartGate1, 71)));
    vm.stopBroadcast();

    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.removeCharacterException, (smartGate1, 71)));
    bool characterException = GatesCharacterExceptions.get(smartGate1, 71);
    assertTrue(characterException);
    vm.stopBroadcast();
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
