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

import { CorporationsTable, CorporationsTableData } from "../src/codegen/tables/CorporationsTable.sol";
import { CorporationsTickers } from "../src/codegen/tables/CorporationsTickers.sol";
import { CorporationsSystem } from "../src/systems/CorporationsSystem.sol";
import { CorporationsSystemErrors } from "../src/systems/CorporationsSystemErrors.sol";
import { Utils } from "../src/systems/Utils.sol";

contract CorporationsTest is MudTest {
  using WorldResourceIdInstance for ResourceId;
  IWorldWithContext private world;

  uint256 private smartCharacterTypeId;
  bytes32 private tenantId;

  uint256 private corp1 = 70000001;
  uint256 private corp2 = 70000002;
  uint256 private corp3 = 70000003;
  uint256 private corp4 = 70000004;

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
      abi.encodePacked(vm.envOr("CORPORATIONS_NAMESPACE", vm.envString("DEFAULT_NAMESPACE")))
    );
    systemId = Utils.corporationsSystemId(namespace);

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
        corp1,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 42, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "beauKode", dappURL: "https://evedataco.re", description: "EVE Datacore website" })
      );
    }
    if (CharactersByAccount.get(player1) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player1"],
        player1,
        corp1,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 71, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player1", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player2) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player2"],
        player2,
        corp2,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 72, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player2", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player3) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player3"],
        player3,
        corp3,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 73, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player3", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player4) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player4"],
        player4,
        corp4,
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 74, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player4", dappURL: "", description: "" })
      );
    }

    // A corp claimed by the admin
    CorporationsTable.set(
      corp1,
      characters["admin"],
      "CORP1",
      block.timestamp,
      "Corp1 Name",
      "https://corp1.com",
      "Corp1 Description"
    );
    CorporationsTickers.set("CORP1", corp1);

    // A corp claimed by a player
    CorporationsTable.set(corp2, characters["player2"], "CORP2", block.timestamp, "Corp2 Name", "", "");
    CorporationsTickers.set("CORP2", corp2);

    // A corp where the CEO is not a member of the corp anymore
    CorporationsTable.set(corp3, characters["player1"], "CORP3", block.timestamp, "Corp3 Name", "", "");
    CorporationsTickers.set("CORP3", corp3);

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
    assertTrue(CharactersByAccount.get(admin) != 0);
  }

  // Test if the corps are claimed
  function testCorpsClaimedDbStatus() public {
    assertTrue(CorporationsTable.getCEO(corp1) == characters["admin"]);
    assertTrue(CorporationsTable.getCEO(corp2) == characters["player2"]);
    assertTrue(CorporationsTable.getCEO(corp3) == characters["player1"]);
    assertTrue(CorporationsTable.getCEO(corp4) == 0);
  }

  function testRevertClaimNotMemberOfCorp() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(
        CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp.selector,
        corp2,
        characters["admin"]
      )
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

    assertTrue(CorporationsTable.getCEO(corp4) == characters["player4"]);
    assertTrue(CorporationsTable.getTicker(corp4) == "CORP4");
    assertTrue(
      keccak256(abi.encodePacked(CorporationsTable.getName(corp4))) == keccak256(abi.encodePacked("Corp4 Name"))
    );
    assertTrue(CorporationsTable.getClaimedAt(corp4) != 0);
    assertTrue(keccak256(abi.encodePacked(CorporationsTable.getDescription(corp4))) == keccak256(abi.encodePacked("")));
    assertTrue(keccak256(abi.encodePacked(CorporationsTable.getHomepage(corp4))) == keccak256(abi.encodePacked("")));
    assertTrue(CorporationsTickers.get("CORP4") == corp4);
  }

  function testRevertClaimTickerAlreadyTaken() public {
    // Try to claim another corp with a ticker that is already taken
    vm.prank(player4);
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_TickerAlreadyTaken.selector, bytes8("CORP3"))
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, "CORP3", "Corp4 Name")));
  }

  function testClaimCeoAsLeftCorp() public {
    vm.prank(player3);
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp3, "CORP3", "Corp3 Name")));

    assertTrue(CorporationsTable.getCEO(corp3) == characters["player3"]);
    assertTrue(CorporationsTable.getTicker(corp3) == "CORP3");
    assertTrue(
      keccak256(abi.encodePacked(CorporationsTable.getName(corp3))) == keccak256(abi.encodePacked("Corp3 Name"))
    );
    assertTrue(CorporationsTable.getClaimedAt(corp3) != 0);
    assertTrue(keccak256(abi.encodePacked(CorporationsTable.getDescription(corp3))) == keccak256(abi.encodePacked("")));
    assertTrue(keccak256(abi.encodePacked(CorporationsTable.getHomepage(corp3))) == keccak256(abi.encodePacked("")));
  }

  function testRevertTransferNotMemberOfCorp() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(
        CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp.selector,
        corp1,
        characters["player4"]
      )
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, characters["player4"])));
  }

  function testRevertTransferNotCEO() public {
    vm.prank(player1);
    vm.expectRevert(
      abi.encodeWithSelector(
        CorporationsSystemErrors.CorporationsSystem_Unauthorized.selector,
        corp1,
        characters["player1"]
      )
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, characters["admin"])));
  }

  function testRevertTransferIsAlreadyCeo() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(
        CorporationsSystemErrors.CorporationsSystem_IsAlreadyCeo.selector,
        corp1,
        characters["admin"]
      )
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, characters["admin"])));
  }

  function testTransfer() public {
    assertTrue(CorporationsTable.getCEO(corp1) == characters["admin"]);

    vm.prank(admin);
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, characters["player1"])));

    assertTrue(CorporationsTable.getCEO(corp1) == characters["player1"]);
  }

  function testRevertClaimEmptyName() public {
    vm.prank(player4);
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, "", 1, 50)
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, "CORP4", "")));
  }

  function testRevertClaimTooLongName() public {
    vm.prank(player4);
    string memory longName = "This corporation name is way too long and should not be accepted";
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, longName, 1, 50)
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, "CORP4", longName)));
  }

  function testRevertClaimInvalidTickerFormat() public {
    vm.startBroadcast(player4);

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector, bytes8(" "))
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, " ", "Corp4 Name")));

    vm.expectRevert(
      abi.encodeWithSelector(
        CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector,
        bytes8(unicode"è")
      )
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, unicode"è", "Corp4 Name")));

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector, bytes8(""))
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, "", "Corp4 Name")));

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector, bytes8("ABCDEF"))
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp4, "ABCDEF", "Corp4 Name")));

    vm.stopBroadcast();
  }

  function testSetMetadata() public {
    vm.prank(admin);
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "New Corp Name", "New description", "https://newcorp.com"))
    );

    assertTrue(
      keccak256(abi.encodePacked(CorporationsTable.getName(corp1))) == keccak256(abi.encodePacked("New Corp Name"))
    );
    assertTrue(
      keccak256(abi.encodePacked(CorporationsTable.getDescription(corp1))) ==
        keccak256(abi.encodePacked("New description"))
    );
    assertTrue(
      keccak256(abi.encodePacked(CorporationsTable.getHomepage(corp1))) ==
        keccak256(abi.encodePacked("https://newcorp.com"))
    );
  }

  function testRevertSetMetadataNotCEO() public {
    vm.prank(player1);
    vm.expectRevert(
      abi.encodeWithSelector(
        CorporationsSystemErrors.CorporationsSystem_Unauthorized.selector,
        corp1,
        characters["player1"]
      )
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "New Corp Name", "New description", "https://newcorp.com"))
    );
  }

  function testRevertSetMetadataInvalidStringLength() public {
    vm.startBroadcast(admin);

    string memory longName = "This corporation name is way too long and should not be accepted";
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, longName, 1, 50)
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, longName, "New description", "https://newcorp.com"))
    );

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, "", 1, 50)
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "", "New description", "https://newcorp.com"))
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
        CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector,
        longDescription,
        0,
        4000
      )
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "New Corp Name", longDescription, "https://newcorp.com"))
    );

    string
      memory longUrl = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor.";
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, longUrl, 0, 255)
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "New Corp Name", "New description", longUrl))
    );

    vm.stopBroadcast();
  }

  function testIsClaimValid() public {
    // Corp1 is claimed and CEO is member of corp - should be valid
    bool isValid = abi.decode(world.call(systemId, abi.encodeCall(CorporationsSystem.isClaimValid, (corp1))), (bool));
    assertTrue(isValid);

    // Corp2 is claimed and CEO is member of corp - should be valid
    (isValid) = abi.decode(world.call(systemId, abi.encodeCall(CorporationsSystem.isClaimValid, (corp2))), (bool));
    assertTrue(isValid);

    // Corp3 is claimed but CEO is not member of corp - should be invalid
    (isValid) = abi.decode(world.call(systemId, abi.encodeCall(CorporationsSystem.isClaimValid, (corp3))), (bool));
    assertFalse(isValid);

    // Corp4 is unclaimed - should be invalid
    (isValid) = abi.decode(world.call(systemId, abi.encodeCall(CorporationsSystem.isClaimValid, (corp4))), (bool));
    assertFalse(isValid);
  }

  function testGetMetadata() public {
    CorporationsTableData memory data1 = abi.decode(
      world.call(systemId, abi.encodeCall(CorporationsSystem.getMetadata, (corp1))),
      (CorporationsTableData)
    );
    assertEq(data1.CEO, characters["admin"]);
    assertEq(data1.ticker, "CORP1");
    assertEq(data1.claimedAt, block.timestamp);
    assertEq(data1.name, "Corp1 Name");
    assertEq(data1.homepage, "https://corp1.com");
    assertEq(data1.description, "Corp1 Description");

    CorporationsTableData memory data2 = abi.decode(
      world.call(systemId, abi.encodeCall(CorporationsSystem.getMetadata, (corp2))),
      (CorporationsTableData)
    );
    assertEq(data2.CEO, characters["player2"]);
    assertEq(data2.ticker, "CORP2");
    assertEq(data2.claimedAt, block.timestamp);
    assertEq(data2.name, "Corp2 Name");
    assertEq(data2.description, "");
    assertEq(data2.homepage, "");

    CorporationsTableData memory data9 = abi.decode(
      world.call(systemId, abi.encodeCall(CorporationsSystem.getMetadata, (9))),
      (CorporationsTableData)
    );
    assertEq(data9.CEO, 0);
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
