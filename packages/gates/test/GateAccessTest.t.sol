// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { Tenant, CharactersByAccount, EntityRecordMetadata } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";

import { GatesDapp } from "../src/codegen/tables/GatesDapp.sol";
import { Gates } from "../src/codegen/tables/Gates.sol";
import { GatesCorpExceptions } from "../src/codegen/tables/GatesCorpExceptions.sol";
import { GatesCharacterExceptions } from "../src/codegen/tables/GatesCharacterExceptions.sol";

import { GateAccessSystem } from "../src/systems/GateAccessSystem.sol";

import { Utils } from "../src/systems/Utils.sol";

contract GateAccessTest is MudTest {
  using WorldResourceIdInstance for ResourceId;
  IWorldWithContext private world;

  uint256 private smartCharacterTypeId;
  bytes32 private tenantId;

  mapping(string => uint256) private corps;
  mapping(string => uint256) private characters;

  uint256 private deployerPrivateKey;
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

    // Initialize corps mapping
    corps["corp1"] = 70000001;
    corps["corp2"] = 70000002;
    corps["corp3"] = 70000003;
    corps["corp4"] = 70000004;

    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    admin = vm.addr(deployerPrivateKey);
    player1 = vm.addr(vm.envUint("PLAYER1_PRIVATE_KEY"));
    player2 = vm.addr(vm.envUint("PLAYER2_PRIVATE_KEY"));
    player3 = vm.addr(vm.envUint("PLAYER3_PRIVATE_KEY"));
    player4 = vm.addr(vm.envUint("PLAYER4_PRIVATE_KEY"));

    // Convert string to bytes14 using abi.encodePacked
    bytes14 namespace = bytes14(abi.encodePacked(vm.envOr("GATES_NAMESPACE", vm.envString("DEFAULT_NAMESPACE"))));
    systemId = Utils.gatesAccessSystemId(namespace);

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
        corps["corp2"],
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 72, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player2", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player3) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player3"],
        player3,
        corps["corp3"],
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 73, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player3", dappURL: "", description: "" })
      );
    }
    if (CharactersByAccount.get(player4) == 0) {
      smartCharacterSystem.createCharacter(
        characters["player4"],
        player4,
        corps["corp4"],
        EntityRecordParams({ typeId: smartCharacterTypeId, itemId: 74, volume: 0, tenantId: tenantId }),
        EntityMetadataParams({ name: "player4", dappURL: "", description: "" })
      );
    }

    GatesDapp.setDappUrl("https://evedataco.re/dapps/gates");

    EntityRecordMetadata.set(100, "Gate 100", "https://evedataco.re/dapps/gates", "");
    EntityRecordMetadata.set(101, "Gate 101", "https://evedataco.re/dapps/gates", "");
    EntityRecordMetadata.set(999, "Gate 999", "https://evedataco.re/dapps/gates", "");

    Gates.set(100, false, block.timestamp);
    // Corp 1 can access gate 100
    GatesCorpExceptions.set(100, corps["corp1"], true);
    // Corp 2 can access gate 100
    GatesCorpExceptions.set(100, corps["corp2"], true);
    // Player 2 can access gate 100 (Already granted by corp)
    GatesCharacterExceptions.set(100, characters["player2"], true);
    // Player 3 can access gate 100
    GatesCharacterExceptions.set(100, characters["player3"], true);
    // Player 4 cannot access gate 100

    Gates.set(101, true, block.timestamp);
    // Corp 1 cannot access gate 101
    GatesCorpExceptions.set(101, corps["corp1"], true);
    // Player 2 cannot access gate 101
    GatesCharacterExceptions.set(101, characters["player2"], true);
    // Player 3 can access gate 101
    // player 4 can access gate 101

    vm.stopBroadcast();
  }

  function testGate100Access() public {
    // Player 1 can access gate 100
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player1"], 100, 0))),
        (bool)
      )
    );
    // Player 2 can access gate 100
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player2"], 100, 0))),
        (bool)
      )
    );
    // Player 3 can access gate 100
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player3"], 100, 0))),
        (bool)
      )
    );
    // Player 4 cannot access gate 100
    assertFalse(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player4"], 100, 0))),
        (bool)
      )
    );
  }

  function testGate101Access() public {
    // Player 1 cannot access gate 101
    assertFalse(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player1"], 101, 0))),
        (bool)
      )
    );
    // Player 2 cannot access gate 101
    assertFalse(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player2"], 101, 0))),
        (bool)
      )
    );
    // Player 3 can access gate 101
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player3"], 101, 0))),
        (bool)
      )
    );
    // Player 4 can access gate 101
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player4"], 101, 0))),
        (bool)
      )
    );
  }

  function testDenyUnknownGate() public {
    // Player 1 cannot access gate 999
    assertFalse(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player1"], 999, 0))),
        (bool)
      )
    );
    // Player 2 cannot access gate 999
    assertFalse(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player2"], 999, 0))),
        (bool)
      )
    );
    // Player 3 cannot access gate 999
    assertFalse(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player3"], 999, 0))),
        (bool)
      )
    );
    // Player 4 cannot access gate 999
    assertFalse(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player4"], 999, 0))),
        (bool)
      )
    );
  }

  function testDenyUnknownCharacter() public {
    // Unknown character cannot access gate 100
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (99, 100, 0))), (bool)));
    // Unknown character cannot access gate 101
    assertFalse(abi.decode(world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (99, 101, 0))), (bool)));
  }

  function testDisableFilteringIfWrongDappURL() public {
    vm.startBroadcast(deployerPrivateKey);
    EntityRecordMetadata.set(100, "Gate 100", "https://evedataco.re/wrong/url", "");
    vm.stopBroadcast();

    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player1"], 100, 0))),
        (bool)
      )
    );
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player2"], 100, 0))),
        (bool)
      )
    );
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player3"], 100, 0))),
        (bool)
      )
    );
    assertTrue(
      abi.decode(
        world.call(systemId, abi.encodeCall(GateAccessSystem.canJump, (characters["player4"], 100, 0))),
        (bool)
      )
    );
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
