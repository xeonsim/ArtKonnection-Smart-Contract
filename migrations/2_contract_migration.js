var Mycontract = artifacts.require("ArtKonnectionToken");

const name = "test";
const symbol = "ts";

module.exports = function (deployer) {
  deployer.deploy(Mycontract, name, symbol);
};
