// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";
import { EntityRecordOffchainTableData } from "@eveworld/world/src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityRecordData } from "@eveworld/world/src/modules/smart-character/types.sol";
import { SmartCharacterLib } from "@eveworld/world/src/modules/smart-character/SmartCharacterLib.sol";
import { CharactersTable } from "@eveworld/world/src/codegen/tables/CharactersTable.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";
import { CorporationsTable } from "../src/codegen/tables/CorporationsTable.sol";
import { CorporationsSystem } from "../src/systems/CorporationsSystem.sol";
import { CorporationsSystemErrors } from "../src/systems/CorporationsSystemErrors.sol";
import { Utils } from "../src/systems/Utils.sol";

contract CorporationsTest is MudTest {
  using SmartCharacterLib for SmartCharacterLib.World;

  IWorld private world;
  SmartCharacterLib.World private smartCharacter;

  uint256 private corp1 = 70000001;
  uint256 private corp2 = 70000002;
  uint256 private corp3 = 70000003;
  uint256 private corp4 = 70000004;

  address private admin;
  address private player1;
  address private player2;
  address private player3;
  address private player4;

  ResourceId private systemId = Utils.corporationsSystemId();

  //Setup for the tests
  function setUp() public override {
    super.setUp();
    world = IWorld(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    admin = vm.addr(deployerPrivateKey);
    player1 = vm.addr(vm.envUint("PLAYER1_PRIVATE_KEY"));
    player2 = vm.addr(vm.envUint("PLAYER2_PRIVATE_KEY"));
    player3 = vm.addr(vm.envUint("PLAYER3_PRIVATE_KEY"));
    player4 = vm.addr(vm.envUint("PLAYER4_PRIVATE_KEY"));

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
        EntityRecordOffchainTableData({ name: "player2", dappURL: "https://evedataco.re", description: "" }),
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
    // A corp claimed by the admin
    CorporationsTable.set(corp1, 42, "CORP1", block.timestamp, "Corp1 Name", "", "");
    // A corp claimed by a player
    CorporationsTable.set(corp2, 72, "CORP2", block.timestamp, "Corp2 Name", "", "");
    // A corp where the CEO is not a member of the corp anymore
    CorporationsTable.set(corp3, 71, "CORP3", block.timestamp, "Corp3 Name", "", "");
    // Leave the corp4 unclaimed
    vm.stopBroadcast();
  }

  // Test if the world exists
  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  // Test if the admin character exists
  function testAdminExists() public {
    assertTrue(CharactersByAddressTable.get(admin) != 0);
  }

  // Test if the corps are claimed
  function testCorpsClaimedDbStatus() public {
    assertTrue(CorporationsTable.getCEO(corp1) == 42);
    assertTrue(CorporationsTable.getCEO(corp2) == 72);
    assertTrue(CorporationsTable.getCEO(corp3) == 71);
    assertTrue(CorporationsTable.getCEO(corp4) == 0);
  }

  function testRevertClaimNotMemberOfCorp() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp.selector, corp2)
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp2, "TEST", "Test Corp")));
  }

  function testRevertClaimCorpAlreadyClaimed() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_CorpAlreadyClaimed.selector, corp1)
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp1, "TEST", "Test Corp")));
  }

  function testClaimUnclaimedCorp() public {
    vm.prank(player4);
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, "CORP4", "Corp4 Name")));

    assertTrue(CorporationsTable.getCEO(corp4) == 74);
  }

  function testClaimNoCeoCorp() public {
    vm.prank(player3);
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp3, "CORP3", "Corp3 Name")));

    assertTrue(CorporationsTable.getCEO(corp3) == 73);
  }
}
