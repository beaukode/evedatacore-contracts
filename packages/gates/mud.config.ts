import { defineWorld } from "@latticexyz/world";

const namespace = process.env.GATES_NAMESPACE || process.env.DEFAULT_NAMESPACE;

export default defineWorld({
  namespace,
  tables: {
    Gates: {
      schema: {
        gateId: "uint256",
        defaultRule: "bool",
        createdAt: "uint256",
      },
      key: ["gateId"],
    },
    GatesCorpExceptions: {
      schema: {
        gateId: "uint256",
        corpId: "uint256",
        active: "bool",
      },
      key: ["gateId", "corpId"],
    },
    GatesCharacterExceptions: {
      schema: {
        gateId: "uint256",
        characterId: "uint256",
        active: "bool",
      },
      key: ["gateId", "characterId"],
    },
  },
  systems: {
    GateAccessSystem: {
      deploy: {
        registerWorldFunctions: false,
      },
    },
    GateConfigSystem: {
      deploy: {
        registerWorldFunctions: false,
      },
    },
  },
});
