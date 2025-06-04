// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";

import { Tenant, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";

import { TribesTable, TribesTableData } from "../src/codegen/tables/TribesTable.sol";
import { TribesTickers } from "../src/codegen/tables/TribesTickers.sol";
import { TribesSystem } from "../src/systems/TribesSystem.sol";
import { TribesSystemErrors } from "../src/systems/TribesSystemErrors.sol";
import { Utils } from "../src/systems/Utils.sol";

contract TribesTest is MudTest {
  using WorldResourceIdInstance for ResourceId;
  IWorldWithContext private world;

  uint256 private smartCharacterTypeId;
  bytes32 private tenantId;

  uint256 private tribe1 = 70000001;
  uint256 private tribe2 = 70000002;
  uint256 private tribe3 = 70000003;
  uint256 private tribe4 = 70000004;

  mapping(string => uint256) private characters;

  address private admin;
  address private player1;
  address private player2;
  address private player3;
  address private player4;

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
    player3 = vm.addr(vm.envUint("PLAYER3_PRIVATE_KEY"));
    player4 = vm.addr(vm.envUint("PLAYER4_PRIVATE_KEY"));

    // Convert string to bytes14 using abi.encodePacked
    bytes14 namespace = bytes14(
      abi.encodePacked(vm.envOr("TRIBES_NAMESPACE", vm.envString("DEFAULT_NAMESPACE")))
    );
    systemId = Utils.tribesSystemId(namespace);

    characters["admin"] = _calculateObjectId(smartCharacterTypeId, 42, true);
    characters["player1"] = _calculateObjectId(smartCharacterTypeId, 71, true);
    characters["player2"] = _calculateObjectId(smartCharacterTypeId, 72, true);
    characters["player3"] = _calculateObjectId(smartCharacterTypeId, 73, true);
    characters["player4"] = _calculateObjectId(smartCharacterTypeId, 74, true);

    vm.startBroadcast(deployerPrivateKey);

    if (CharactersByAccount.get(admin) == 0) {
      smartCharacterSystem.createCharacter(
        characters["admin"],
        admin,
        tribe1,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 42, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "beauKode", dappURL: "https://evedataco.re", description: "EVE Datacore website" })
      );
    }
    if (CharactersByAccount.get(player1) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player1"],
        player1,
        tribe1,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 71, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player1", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player2) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player2"],
        player2,
        tribe2,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 72, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player2", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player3) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player3"],
        player3,
        tribe3,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 73, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player3", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player4) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player4"],
        player4,
        tribe4,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 74, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player4", dappURL: "", description: "" })
      );
    }

    // A tribe claimed by the admin
    TribesTable.set(
      tribe1,
      characters["admin"],
      "TRIB1",
      block.timestamp,
      "Tribe1 Name",
      "https://tribe1.com",
      "Tribe1 Description"
    );
    TribesTickers.set("TRIB1", tribe1);

    // A tribe claimed by a player
    TribesTable.set(tribe2, characters["player2"], "TRIB2", block.timestamp, "Tribe2 Name", "", "");
    TribesTickers.set("CORP2", tribe2);

    // A tribe where the warlord is not a member of the tribe anymore
    TribesTable.set(tribe3, characters["player1"], "TRIB3", block.timestamp, "Tribe3 Name", "", "");
    TribesTickers.set("TRIB3", tribe3);

    // Leave the tribe4 unclaimed
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
    assertTrue(CharactersByAccount.get(admin) != 0);
  }

  // Test if the tribes are claimed
  function testTribesClaimedDbStatus() public {
    assertTrue(TribesTable.getWarlord(tribe1) == characters["admin"]);
    assertTrue(TribesTable.getWarlord(tribe2) == characters["player2"]);
    assertTrue(TribesTable.getWarlord(tribe3) == characters["player1"]);
    assertTrue(TribesTable.getWarlord(tribe4) == 0);
  }

  function testRevertClaimNotMemberOfTribe() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_NotMemberOfTribe.selector, tribe2, characters["admin"])
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe2, "TEST", "Test Tribe")));
  }

  function testRevertClaimTribeAlreadyClaimed() public {
    vm.prank(admin);
    vm.expectRevert(abi.encodeWithSelector(TribesSystemErrors.TribesSystem_TribeAlreadyClaimed.selector, tribe1));
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe1, "TEST", "Test Tribe")));
  }

  function testClaimUnclaimedTribe() public {
    vm.prank(player4);
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, "TRIB4", "Tribe4 Name")));

    assertTrue(TribesTable.getWarlord(tribe4) == characters["player4"]);
    assertTrue(TribesTable.getTicker(tribe4) == "TRIB4");
    assertTrue(keccak256(abi.encodePacked(TribesTable.getName(tribe4))) == keccak256(abi.encodePacked("Tribe4 Name")));
    assertTrue(TribesTable.getClaimedAt(tribe4) != 0);
    assertTrue(keccak256(abi.encodePacked(TribesTable.getDescription(tribe4))) == keccak256(abi.encodePacked("")));
    assertTrue(keccak256(abi.encodePacked(TribesTable.getHomepage(tribe4))) == keccak256(abi.encodePacked("")));
    assertTrue(TribesTickers.get("TRIB4") == tribe4);
  }

  function testRevertClaimTickerAlreadyTaken() public {
    // Try to claim another tribe with a ticker that is already taken
    vm.prank(player4);
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_TickerAlreadyTaken.selector, bytes8("TRIB3"))
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, "TRIB3", "Tribe4 Name")));
  }

  function testClaimWarlordAsLeftTribe() public {
    vm.prank(player3);
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe3, "TRIB3", "Tribe3 Name")));

    assertTrue(TribesTable.getWarlord(tribe3) == characters["player3"]);
    assertTrue(TribesTable.getTicker(tribe3) == "TRIB3");
    assertTrue(keccak256(abi.encodePacked(TribesTable.getName(tribe3))) == keccak256(abi.encodePacked("Tribe3 Name")));
    assertTrue(TribesTable.getClaimedAt(tribe3) != 0);
    assertTrue(keccak256(abi.encodePacked(TribesTable.getDescription(tribe3))) == keccak256(abi.encodePacked("")));
    assertTrue(keccak256(abi.encodePacked(TribesTable.getHomepage(tribe3))) == keccak256(abi.encodePacked("")));
  }

  function testRevertTransferNotMemberOfTribe() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_NotMemberOfTribe.selector, tribe1, characters["player4"])
    );
    world.call(systemId, abi.encodeCall(TribesSystem.transfer, (tribe1, characters["player4"])));
  }

  function testRevertTransferNotWarlord() public {
    vm.prank(player1);
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_Unauthorized.selector, tribe1, characters["player1"])
    );
    world.call(systemId, abi.encodeCall(TribesSystem.transfer, (tribe1, characters["admin"])));
  }

  function testRevertTransferIsAlreadyWarlord() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_IsAlreadyWarlord.selector, tribe1, characters["admin"])
    );
    world.call(systemId, abi.encodeCall(TribesSystem.transfer, (tribe1, characters["admin"])));
  }

  function testTransfer() public {
    assertTrue(TribesTable.getWarlord(tribe1) == characters["admin"]);

    vm.prank(admin);
    world.call(systemId, abi.encodeCall(TribesSystem.transfer, (tribe1, characters["player1"])));

    assertTrue(TribesTable.getWarlord(tribe1) == characters["player1"]);
  }

  function testRevertClaimEmptyName() public {
    vm.prank(player4);
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidStringLength.selector, "", 1, 50)
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, "TRIB4", "")));
  }

  function testRevertClaimTooLongName() public {
    vm.prank(player4);
    string memory longName = "This tribe name is way too long and should not be accepted";
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidStringLength.selector, longName, 1, 50)
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, "TRIB4", longName)));
  }

  function testRevertClaimInvalidTickerFormat() public {
    vm.startBroadcast(player4);

    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidTickerFormat.selector, bytes8(" "))
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, " ", "Tribe4 Name")));

    vm.expectRevert(
      abi.encodeWithSelector(
        TribesSystemErrors.TribesSystem_InvalidTickerFormat.selector,
        bytes8(unicode"è")
      )
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, unicode"è", "Tribe4 Name")));

    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidTickerFormat.selector, bytes8(""))
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, "", "Tribe4 Name")));

    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidTickerFormat.selector, bytes8("ABCDEF"))
    );
    world.call(systemId, abi.encodeCall(TribesSystem.claim, (tribe4, "ABCDEF", "Tribe4 Name")));

    vm.stopBroadcast();
  }

  function testSetMetadata() public {
    vm.prank(admin);
    world.call(
      systemId,
      abi.encodeCall(TribesSystem.setMetadata, (tribe1, "New Tribe Name", "New description", "https://newtribe.com"))
    );

    assertTrue(
      keccak256(abi.encodePacked(TribesTable.getName(tribe1))) == keccak256(abi.encodePacked("New Tribe Name"))
    );
    assertTrue(
      keccak256(abi.encodePacked(TribesTable.getDescription(tribe1))) ==
        keccak256(abi.encodePacked("New description"))
    );
    assertTrue(
      keccak256(abi.encodePacked(TribesTable.getHomepage(tribe1))) ==
        keccak256(abi.encodePacked("https://newtribe.com"))
    );
  }

  function testRevertSetMetadataNotWarlord() public {
    vm.prank(player1);
    vm.expectRevert(
      abi.encodeWithSelector(
        TribesSystemErrors.TribesSystem_Unauthorized.selector,
        tribe1,
        characters["player1"]
      )
    );
    world.call(
      systemId,
      abi.encodeCall(TribesSystem.setMetadata, (tribe1, "New Tribe Name", "New description", "https://newtribe.com"))
    );
  }

  function testRevertSetMetadataInvalidStringLength() public {
    vm.startBroadcast(admin);

    string memory longName = "This tribe name is way too long and should not be accepted";
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidStringLength.selector, longName, 1, 50)
    );
    world.call(
      systemId,
      abi.encodeCall(TribesSystem.setMetadata, (tribe1, longName, "New description", "https://newtribe.com"))
    );

    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidStringLength.selector, "", 1, 50)
    );
    world.call(
      systemId,
      abi.encodeCall(TribesSystem.setMetadata, (tribe1, "", "New description", "https://newtribe.com"))
    );

    string
      memory longDescription = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tinciduna"
      "L";
    vm.expectRevert(
      abi.encodeWithSelector(
        TribesSystemErrors.TribesSystem_InvalidStringLength.selector,
        longDescription,
        0,
        4000
      )
    );
    world.call(
      systemId,
      abi.encodeCall(TribesSystem.setMetadata, (tribe1, "New Tribe Name", longDescription, "https://newtribe.com"))
    );

    string
      memory longUrl = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor.";
    vm.expectRevert(
      abi.encodeWithSelector(TribesSystemErrors.TribesSystem_InvalidStringLength.selector, longUrl, 0, 255)
    );
    world.call(
      systemId,
      abi.encodeCall(TribesSystem.setMetadata, (tribe1, "New Tribe Name", "New description", longUrl))
    );

    vm.stopBroadcast();
  }

  function testIsClaimValid() public {
    // Tribe1 is claimed and warlord is member of tribe - should be valid
    bool isValid = abi.decode(world.call(systemId, abi.encodeCall(TribesSystem.isClaimValid, (tribe1))), (bool));
    assertTrue(isValid);

    // Tribe2 is claimed and warlord is member of tribe - should be valid
    (isValid) = abi.decode(world.call(systemId, abi.encodeCall(TribesSystem.isClaimValid, (tribe2))), (bool));
    assertTrue(isValid);

    // Tribe3 is claimed but warlord is not member of tribe - should be invalid
    (isValid) = abi.decode(world.call(systemId, abi.encodeCall(TribesSystem.isClaimValid, (tribe3))), (bool));
    assertFalse(isValid);

    // Tribe4 is unclaimed - should be invalid
    (isValid) = abi.decode(world.call(systemId, abi.encodeCall(TribesSystem.isClaimValid, (tribe4))), (bool));
    assertFalse(isValid);
  }

  function testGetMetadata() public {
    TribesTableData memory data1 = abi.decode(
      world.call(systemId, abi.encodeCall(TribesSystem.getMetadata, (tribe1))),
      (TribesTableData)
    );
    assertEq(data1.warlord, characters["admin"]);
    assertEq(data1.ticker, "TRIB1");
    assertEq(data1.claimedAt, block.timestamp);
    assertEq(data1.name, "Tribe1 Name");
    assertEq(data1.homepage, "https://tribe1.com");
    assertEq(data1.description, "Tribe1 Description");

    TribesTableData memory data2 = abi.decode(
      world.call(systemId, abi.encodeCall(TribesSystem.getMetadata, (tribe2))),
      (TribesTableData)
    );
    assertEq(data2.warlord, characters["player2"]);
    assertEq(data2.ticker, "TRIB2");
    assertEq(data2.claimedAt, block.timestamp);
    assertEq(data2.name, "Tribe2 Name");
    assertEq(data2.description, "");
    assertEq(data2.homepage, "");

    TribesTableData memory data9 = abi.decode(
      world.call(systemId, abi.encodeCall(TribesSystem.getMetadata, (9))),
      (TribesTableData)
    );
    assertEq(data9.warlord, 0);
    assertEq(data9.ticker, "");
    assertEq(data9.claimedAt, 0);
    assertEq(data9.name, "");
    assertEq(data9.homepage, "");
    assertEq(data9.description, "");
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
