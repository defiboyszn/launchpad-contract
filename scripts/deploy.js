const hre = require("hardhat");

async function main() {
  const LaunchPadDeployer = await hre.ethers.getContractFactory("LaunchPadDeployer");
  const tokendeploy = await LaunchPadDeployer.deploy();

  await tokendeploy.deployed();
  console.log("LaunchPadDeployer deployed to: ", tokendeploy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });