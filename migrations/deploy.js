const LostPet = artifacts.require("LostPet");

module.exports = function (deployer) {
  deployer.deploy(LostPet);
};