import { defineWorld } from "@latticexyz/world";

const namespace = process.env.TRIBES_NAMESPACE || process.env.DEFAULT_NAMESPACE;

export default defineWorld({
  namespace,
  tables: {
    TribesTable: {
      schema: {
        tribeId: "uint256",
        warlord: "uint256",
        ticker: "bytes8",
        claimedAt: "uint256",
        name: "string",
        homepage: "string",
        description: "string",
      },
      key: ["tribeId"],
    },
    TribesTickers: {
      schema: {
        ticker: "bytes8",
        tribeId: "uint256",
      },
      key: ["ticker"],
    },
  },
  systems: {
    TribesSystem: {
      deploy: {
        registerWorldFunctions: false,
      },
    },
  },
});
