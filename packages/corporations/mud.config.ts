import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "beauKode_dev",
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
