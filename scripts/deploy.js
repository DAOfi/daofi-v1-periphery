async function main() {

  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  console.log("Deployer ccount balance:", (await deployer.getBalance()).toString());

  const UniswapV2Router02 = await ethers.getContractFactory("contracts/UniswapV2Router02.sol:UniswapV2Router02");
  const router = await UniswapV2Router02.deploy();

  console.log("Router address:", router.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });