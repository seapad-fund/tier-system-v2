const {buildModule} = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Token", (m) => {
  const token = m.contract("Token", ["Token A", "TKA", 10000]);

  return {token};
});
