const main = async () => {
    const [owner, randomPerson] = await hre.ethers.getSigners();
    
  }
  
  const runMain = async () => {
    try {
      await main();
      process.exit(0);
    } catch (error) {
      console.log(error);
      process.exit(1);
    }
  };
  
  runMain();