import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "beauKode_dev",
  tables: {
    TestTable1: {
      schema: {
        key: "uint256",
        valueA: "address",
        valueB: "bool",
        valueU: "uint256",
        valueS: "string",
      },
      key: ["key"],
    },
    TestTable2: {
      schema: {
        id: "uint256",
        owner: "address",
        valueB: "bool[]",
        valueU: "uint256[]",
        valueI8: "int8[]",
        valueA: "address[]",
        valueBy: "bytes8[]",
      },
      key: ["id", "owner"],
    },
    SmartGateAccess: {
      schema: {
        gateId: "uint256",
        corporations: "uint256[]",
        characters: "uint256[]",
      },
      key: ["gateId"],
    },
  },
});
