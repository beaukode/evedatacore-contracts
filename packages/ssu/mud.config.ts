import { defineWorld } from "@latticexyz/world";

const namespace = process.env.SSU_NAMESPACE || process.env.DEFAULT_NAMESPACE;

export default defineWorld({
  namespace,
  tables: {},
  systems: {
    SSUSystem: {
      deploy: {
        registerWorldFunctions: false,
      },
    },
  },
});
