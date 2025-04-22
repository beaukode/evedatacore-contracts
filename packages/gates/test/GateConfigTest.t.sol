// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";
import { EntityRecordOffchainTableData } from "@eveworld/world/src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityRecordData as EntityRecordDataCharacter } from "@eveworld/world/src/modules/smart-character/types.sol";
import { SmartCharacterLib } from "@eveworld/world/src/modules/smart-character/SmartCharacterLib.sol";
import { SmartDeployableLib } from "@eveworld/world/src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartObjectData } from "@eveworld/world/src/modules/smart-deployable/types.sol";
import { SmartGateLib } from "@eveworld/world/src/modules/smart-gate/SmartGateLib.sol";
import { EntityRecordData, WorldPosition, Coord } from "@eveworld/world/src/modules/smart-storage-unit/types.sol";

import { Gates, GatesData } from "../src/codegen/tables/Gates.sol";
import { GatesCorpExceptions } from "../src/codegen/tables/GatesCorpExceptions.sol";
import { GatesCharacterExceptions } from "../src/codegen/tables/GatesCharacterExceptions.sol";

import { GateConfigSystem } from "../src/systems/GateConfigSystem.sol";
import { GateConfigErrors } from "../src/systems/GateConfigErrors.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";
import { Utils } from "../src/systems/Utils.sol";

contract CorporationsTest is MudTest {
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartGateLib for SmartGateLib.World;

  IWorld private world;
  SmartCharacterLib.World private smartCharacter;
  SmartDeployableLib.World private smartDeployable;
  SmartGateLib.World private smartGate;

  uint256 private corp1 = 70000001;
  uint256 private corp2 = 70000002;

  address private admin;
  address private player1;
  address private player2;

  ResourceId private systemId;

  //Setup for the tests
  function setUp() public override {
    super.setUp();
    world = IWorld(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    admin = vm.addr(deployerPrivateKey);
    player1 = vm.addr(vm.envUint("PLAYER1_PRIVATE_KEY"));
    player2 = vm.addr(vm.envUint("PLAYER2_PRIVATE_KEY"));

    // Convert string to bytes14 using abi.encodePacked
    bytes14 namespace = bytes14(abi.encodePacked(vm.envOr("GATES_NAMESPACE", vm.envString("DEFAULT_NAMESPACE"))));
    systemId = Utils.gatesConfigSystemId(namespace);

    smartCharacter = SmartCharacterLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });
    smartDeployable = SmartDeployableLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    smartGate = SmartGateLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);

    if (CharactersByAddressTable.get(admin) == 0) {
      smartCharacter.createCharacter(
        42,
        admin,
        corp1,
        EntityRecordDataCharacter({ typeId: 123, itemId: 0, volume: 0 }),
        EntityRecordOffchainTableData({
          name: "beauKode",
          dappURL: "https://evedataco.re",
          description: "EVE Datacore website"
        }),
        ""
      );
    }
    if (CharactersByAddressTable.get(player1) == 0) {
      smartCharacter.createCharacter(
        71,
        player1,
        corp1,
        EntityRecordDataCharacter({ typeId: 123, itemId: 0, volume: 0 }),
        EntityRecordOffchainTableData({ name: "player1", dappURL: "", description: "" }),
        ""
      );
    }
    if (CharactersByAddressTable.get(player2) == 0) {
      smartCharacter.createCharacter(
        72,
        player2,
        corp2,
        EntityRecordDataCharacter({ typeId: 123, itemId: 0, volume: 0 }),
        EntityRecordOffchainTableData({ name: "player2", dappURL: "", description: "" }),
        ""
      );
    }

    vm.startBroadcast(deployerPrivateKey);

    createSmartGate(100);
    createSmartGate(101);

    vm.stopBroadcast();
  }

  function createSmartGate(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: player1, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({
      solarSystemId: 1,
      position: Coord({ x: 10000, y: 10000, z: 10000 })
    });

    smartGate.createAndAnchorSmartGate(
      smartObjectId,
      entityRecordData,
      smartObjectData,
      worldPosition,
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionIntervalInSeconds,
      1000000 * 1e18, // fuelMaxCapacity,
      100000000 * 1e18 // maxDistance
    );

    smartDeployable.depositFuel(smartObjectId, 100000);
    smartDeployable.bringOnline(smartObjectId);
  }

  function testInitialRegistrationWithTrueDefaultRule() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (100, true)));

    // Gate 100 is registered and default rule is true
    GatesData memory gateData = Gates.get(100);
    assertEq(gateData.createdAt, block.timestamp);
    assertEq(gateData.defaultRule, true);

    // Gate 101 is not registered yet
    gateData = Gates.get(101);
    assertEq(gateData.createdAt, 0);
    assertEq(gateData.defaultRule, false);

    vm.stopBroadcast();
  }

  function testInitialRegistrationWithFalseDefaultRule() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (100, false)));

    // Gate 100 is registered and default rule is false
    GatesData memory gateData = Gates.get(100);
    assertEq(gateData.createdAt, block.timestamp);
    assertEq(gateData.defaultRule, false);

    // Gate 101 is not registered yet
    gateData = Gates.get(101);
    assertEq(gateData.createdAt, 0);
    assertEq(gateData.defaultRule, false);

    vm.stopBroadcast();
  }

  function testInitialRegistrationRevertIfNotOwner() public {
    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (100, true)));

    // Gate 100 still not registered
    GatesData memory gateData = Gates.get(100);
    assertEq(gateData.createdAt, 0);
    assertEq(gateData.defaultRule, false);

    vm.stopBroadcast();
  }

  function testUpdateDefaultRule() public {
    vm.startBroadcast(player1);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (100, false)));
    uint256 currentTimestamp = block.timestamp;

    // Gate 100 is registered and default rule is false
    GatesData memory gateData = Gates.get(100);
    assertEq(gateData.createdAt, currentTimestamp);
    assertEq(gateData.defaultRule, false);

    vm.warp(block.timestamp + 100);
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (100, true)));

    // Gate 100 is registered and default rule is true
    gateData = Gates.get(100);
    assertEq(gateData.createdAt, currentTimestamp); // createdAt should not be updated
    assertEq(gateData.defaultRule, true);

    vm.stopBroadcast();
  }

  function testUpdateDefaultRuleRevertIfNotOwner() public {
    vm.startBroadcast(player2);
    vm.expectRevert(abi.encodeWithSelector(GateConfigErrors.GateConfig_Unauthorized.selector, player2, player1));
    world.call(systemId, abi.encodeCall(GateConfigSystem.setDefaultRule, (100, true)));
    vm.stopBroadcast();
  }
}
