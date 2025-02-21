import { defineWorld } from "@latticexyz/world";

const namespace = process.env.CORPORATIONS_NAMESPACE || process.env.DEFAULT_NAMESPACE;

export default defineWorld({
  namespace,
  tables: {
    CorporationsTable: {
      schema: {
        corpId: "uint256",
        CEO: "uint256",
        ticker: "bytes8",
        claimedAt: "uint256",
        name: "string",
        homepage: "string",
        description: "string",
      },
      key: ["corpId"],
    },
  },
  systems: {
    CorporationsSystem: {
      deploy: {
        registerWorldFunctions: false,
      },
    },
  },
});
