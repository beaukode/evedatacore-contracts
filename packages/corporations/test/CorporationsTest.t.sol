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
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp.selector, corp2, 42)
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
    assertTrue(CorporationsTable.getTicker(corp4) == "CORP4");
    assertTrue(
      keccak256(abi.encodePacked(CorporationsTable.getName(corp4))) == keccak256(abi.encodePacked("Corp4 Name"))
    );
    assertTrue(CorporationsTable.getClaimedAt(corp4) != 0);
    assertTrue(keccak256(abi.encodePacked(CorporationsTable.getDescription(corp4))) == keccak256(abi.encodePacked("")));
    assertTrue(keccak256(abi.encodePacked(CorporationsTable.getHomepage(corp4))) == keccak256(abi.encodePacked("")));
  }

  function testClaimCeoAsLeftCorp() public {
    vm.prank(player3);
    world.call(systemId, abi.encodeCall(CorporationsSystem.claim, (corp3, "CORP3", "Corp3 Name")));

    assertTrue(CorporationsTable.getCEO(corp3) == 73);
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
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_NotMemberOfCorp.selector, corp1, 74)
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, 74)));
  }

  function testRevertTransferNotCEO() public {
    vm.prank(player1);
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_Unauthorized.selector, corp1, 71)
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, 42)));
  }

  function testRevertTransferIsAlreadyCeo() public {
    vm.prank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_IsAlreadyCeo.selector, corp1, 42)
    );
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, 42)));
  }

  function testTransfer() public {
    assertTrue(CorporationsTable.getCEO(corp1) == 42);

    vm.prank(admin);
    world.call(systemId, abi.encodeCall(CorporationsSystem.transfer, (corp1, 71)));

    assertTrue(CorporationsTable.getCEO(corp1) == 71);
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
      abi.encodeCall(
        CorporationsSystem.setMetadata,
        (corp1, "NEW", "New Corp Name", "New description", "https://newcorp.com")
      )
    );

    assertTrue(CorporationsTable.getTicker(corp1) == "NEW");
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
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_Unauthorized.selector, corp1, 71)
    );
    world.call(
      systemId,
      abi.encodeCall(
        CorporationsSystem.setMetadata,
        (corp1, "NEW", "New Corp Name", "New description", "https://newcorp.com")
      )
    );
  }

  function testRevertSetMetadataInvalidTickerFormat() public {
    vm.startBroadcast(admin);

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector, bytes8(" "))
    );
    world.call(
      systemId,
      abi.encodeCall(
        CorporationsSystem.setMetadata,
        (corp1, " ", "New Corp Name", "New description", "https://newcorp.com")
      )
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector,
        bytes8(unicode"è")
      )
    );
    world.call(
      systemId,
      abi.encodeCall(
        CorporationsSystem.setMetadata,
        (corp1, unicode"è", "New Corp Name", "New description", "https://newcorp.com")
      )
    );

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector, bytes8(""))
    );
    world.call(
      systemId,
      abi.encodeCall(
        CorporationsSystem.setMetadata,
        (corp1, "", "New Corp Name", "New description", "https://newcorp.com")
      )
    );

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidTickerFormat.selector, bytes8("ABCDEF"))
    );
    world.call(
      systemId,
      abi.encodeCall(
        CorporationsSystem.setMetadata,
        (corp1, "ABCDEF", "New Corp Name", "New description", "https://newcorp.com")
      )
    );

    vm.stopBroadcast();
  }

  function testRevertSetMetadataInvalidStringLength() public {
    vm.startBroadcast(admin);

    string memory longName = "This corporation name is way too long and should not be accepted";
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, longName, 1, 50)
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "NEW", longName, "New description", "https://newcorp.com"))
    );

    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, "", 1, 50)
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "NEW", "", "New description", "https://newcorp.com"))
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
      abi.encodeCall(
        CorporationsSystem.setMetadata,
        (corp1, "NEW", "New Corp Name", longDescription, "https://newcorp.com")
      )
    );

    string
      memory longUrl = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vitae augue laoreet, ultrices ante non, ultrices metus. Nullam lobortis, sem imperdiet tempor faucibus, mauris nisl cursus justo, quis eleifend neque nulla eu urna. Praesent tincidunt, orci dolor.";
    vm.expectRevert(
      abi.encodeWithSelector(CorporationsSystemErrors.CorporationsSystem_InvalidStringLength.selector, longUrl, 0, 255)
    );
    world.call(
      systemId,
      abi.encodeCall(CorporationsSystem.setMetadata, (corp1, "NEW", "New Corp Name", "New description", longUrl))
    );

    vm.stopBroadcast();
  }
}
