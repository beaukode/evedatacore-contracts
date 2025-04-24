// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "@eveworld/world/src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityRecordData } from "@eveworld/world/src/modules/smart-character/types.sol";
import { SmartCharacterLib } from "@eveworld/world/src/modules/smart-character/SmartCharacterLib.sol";

import { GatesDapp } from "../src/codegen/tables/GatesDapp.sol";
import { Gates } from "../src/codegen/tables/Gates.sol";
import { GatesCorpExceptions } from "../src/codegen/tables/GatesCorpExceptions.sol";
import { GatesCharacterExceptions } from "../src/codegen/tables/GatesCharacterExceptions.sol";

import { GateAccessSystem } from "../src/systems/GateAccessSystem.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";
import { Utils } from "../src/systems/Utils.sol";

contract CorporationsTest is MudTest {
  using SmartCharacterLib for SmartCharacterLib.World;

  IWorld private world;
  SmartCharacterLib.World private smartCharacter;

  uint256 private corp1 = 70000001;
  uint256 private corp2 = 70000002;
  uint256 private corp3 = 70000003;
  uint256 private corp4 = 70000004;

  uint256 private deployerPrivateKey;
  address private admin;
  address private player1;
  address private player2;
  address private player3;
  address private player4;

  ResourceId private systemId;

  //Setup for the tests
  function setUp() public override {
    super.setUp();
    world = IWorld(worldAddress);

    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    admin = vm.addr(deployerPrivateKey);
    player1 = vm.addr(vm.envUint("PLAYER1_PRIVATE_KEY"));
    player2 = vm.addr(vm.envUint("PLAYER2_PRIVATE_KEY"));
    player3 = vm.addr(vm.envUint("PLAYER3_PRIVATE_KEY"));
    player4 = vm.addr(vm.envUint("PLAYER4_PRIVATE_KEY"));

    // Convert string to bytes14 using abi.encodePacked
    bytes14 namespace = bytes14(abi.encodePacked(vm.envOr("GATES_NAMESPACE", vm.envString("DEFAULT_NAMESPACE"))));
    systemId = Utils.gatesAccessSystemId(namespace);

    smartCharacter = SmartCharacterLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    if (CharactersByAddressTable.get(admin) == 0) {
      smartCharacter.createCharacter(
        42,
        admin,
        corp1,
        EntityRecordData({ typeId: 123, itemId: 0, volume: 0 }),
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
        EntityRecordData({ typeId: 123, itemId: 0, volume: 0 }),
        EntityRecordOffchainTableData({ name: "player1", dappURL: "", description: "" }),
        ""
      );
    }
    if (CharactersByAddressTable.get(player2) == 0) {
      smartCharacter.createCharacter(
        72,
        player2,
        corp2,
        EntityRecordData({ typeId: 123, itemId: 0, volume: 0 }),
        EntityRecordOffchainTableData({ name: "player2", dappURL: "", description: "" }),
        ""
      );
    }
    if (CharactersByAddressTable.get(player3) == 0) {
      smartCharacter.createCharacter(
        73,
        player3,
        corp3,
        EntityRecordData({ typeId: 123, itemId: 0, volume: 0 }),
        EntityRecordOffchainTableData({ name: "player3", dappURL: "", description: "" }),
        ""
      );
    }
    if (CharactersByAddressTable.get(player4) == 0) {
      smartCharacter.createCharacter(
        74,
        player4,
        corp4,
        EntityRecordData({ typeId: 123, itemId: 0, volume: 0 }),
        EntityRecordOffchainTableData({ name: "player4", dappURL: "", description: "" }),
        ""
      );
    }

    vm.startBroadcast(deployerPrivateKey);

    GatesDapp.setDappUrl("https://evedataco.re/dapps/gates");

    EntityRecordOffchainTable.set(
      100,
      EntityRecordOffchainTableData({ name: "Gate 100", dappURL: "https://evedataco.re/dapps/gates", description: "" })
    );
    EntityRecordOffchainTable.set(
      101,
      EntityRecordOffchainTableData({ name: "Gate 101", dappURL: "https://evedataco.re/dapps/gates", description: "" })
    );
    EntityRecordOffchainTable.set(
      999,
      EntityRecordOffchainTableData({ name: "Gate 999", dappURL: "https://evedataco.re/dapps/gates", description: "" })
    );

    Gates.set(100, false, block.timestamp);
    // Corp 1 can access gate 100
    GatesCorpExceptions.set(100, corp1, true);
    // Corp 2 can access gate 100
    GatesCorpExceptions.set(100, corp2, true);
    // Player 2 can access gate 100 (Already granted by corp)
    GatesCharacterExceptions.set(100, 72, true);
    // Player 3 can access gate 100
    GatesCharacterExceptions.set(100, 73, true);
    // Player 4 cannot access gate 100

    Gates.set(101, true, block.timestamp);
    // Corp 1 cannot access gate 101
    GatesCorpExceptions.set(101, corp1, true);
    // Player 2 cannot access gate 101
    GatesCharacterExceptions.set(101, 72, true);
    // Player 3 can access gate 101
    // player 4 can access gate 101

    vm.stopBroadcast();
  }

  function testGate100Access() public {
    // Player 1 can access gate 100
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (71, 100, 0))), (bool)));
    // Player 2 can access gate 100
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (72, 100, 0))), (bool)));
    // Player 3 can access gate 100
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (73, 100, 0))), (bool)));
    // Player 4 cannot access gate 100
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (74, 100, 0))), (bool)));
  }

  function testGate101Access() public {
    // Player 1 cannot access gate 101
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (71, 101, 0))), (bool)));
    // Player 2 cannot access gate 101
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (72, 101, 0))), (bool)));
    // Player 3 can access gate 101
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (73, 101, 0))), (bool)));
    // Player 4 can access gate 101
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (74, 101, 0))), (bool)));
  }

  function testDenyUnknownGate() public {
    // Player 1 cannot access gate 999
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (71, 999, 0))), (bool)));
    // Player 2 cannot access gate 999
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (72, 999, 0))), (bool)));
    // Player 3 cannot access gate 999
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (73, 999, 0))), (bool)));
    // Player 4 cannot access gate 999
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (74, 999, 0))), (bool)));
  }

  function testDenyUnknownCharacter() public {
    // Unknown character cannot access gate 100
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (99, 100, 0))), (bool)));
    // Unknown character cannot access gate 101
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (99, 101, 0))), (bool)));
  }

  function testDisableFilteringIfWrongDappURL() public {
    vm.startBroadcast(deployerPrivateKey);
    EntityRecordOffchainTable.set(
      100,
      EntityRecordOffchainTableData({ name: "Gate 100", dappURL: "https://evedataco.re/wrong/url", description: "" })
    );
    vm.stopBroadcast();

    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (71, 100, 0))), (bool)));
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (72, 100, 0))), (bool)));
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (73, 100, 0))), (bool)));
    assertTrue(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (74, 100, 0))), (bool)));  
  }
}
