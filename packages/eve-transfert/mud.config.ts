import { defineWorld } from "@latticexyz/world";

const namespace = process.env.EVE_TRANSFERT_NAMESPACE || process.env.DEFAULT_NAMESPACE;

export default defineWorld({
  namespace,
  systems: {
    EVETransfertSystem: {
      deploy: {
        registerWorldFunctions: false,
      },
    },
  },
});
