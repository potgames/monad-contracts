module.exports = [
    "0x754BAEED583a13E9521F5F7d0d7146Ba1DF1262c",  // Oracle address
    "0xA62D778567d0690C64e99bA49BEA66Be284378AB",               // Admin address
    "0x138A0e1304C25B3e272099A2491890e5eADA3Eb3",    // Operator address
    60,                          // intervalSeconds (5 minutes)
    30,                           // bufferSeconds (30 seconds)
    ethers.parseEther("0.01"),     // minEntry
    60,                           // oracleUpdateAllowance
    200    
]
