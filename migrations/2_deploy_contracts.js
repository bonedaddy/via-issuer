// (c) Kallol Borah, 2020
// deploying via tokens

const stringutils = artifacts.require('stringutils');
const ABDKMathQuad = artifacts.require('ABDKMathQuad');
const Factory = artifacts.require('Factory');
const Bond = artifacts.require('Bond');
const Cash = artifacts.require('Cash');
const ViaOracle = artifacts.require('ViaOracle');
const usingProvable = artifacts.require('usingProvable');
const ERC20 = artifacts.require('ERC20');
const Token = artifacts.require('Token');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async function(deployer, network, accounts) {

    await deployProxy(stringutils, {deployer});
    // await deployer.deploy(stringutils);
    await deployer.link(stringutils, [Bond, Cash, ViaOracle]);

    await deployProxy(ABDKMathQuad, {deployer});
    // await deployer.deploy(ABDKMathQuad);
    await deployer.link(ABDKMathQuad,[Cash, Bond, ViaOracle, ERC20, Token]);

    await deployer.deploy(ViaOracle, {from: accounts[0], gas:6721975, value: 0.25e18});

    await deployProxy(Cash, {deployer});
    // await deployer.deploy(Cash);
    await deployProxy(Bond, {deployer});
    // await deployer.deploy(Bond);
    await deployProxy(Token, {deployer});
    // await deployer.deploy(Token);

    await deployer.deploy(Factory).then(async () => {
        const factory = await Factory.deployed();
        const cash = await Cash.deployed();
        const bond = await Bond.deployed();
        const oracle = await ViaOracle.deployed();
        const token = await Token.deployed();

        await oracle.initialize(factory.address);

        await factory.createIssuer(cash.address, web3.utils.utf8ToHex("Via_USD"), web3.utils.utf8ToHex("Cash"), oracle.address, token.address);
        await factory.createIssuer(cash.address, web3.utils.utf8ToHex("Via_EUR"), web3.utils.utf8ToHex("Cash"), oracle.address, token.address);
        await factory.createIssuer(cash.address, web3.utils.utf8ToHex("Via_INR"), web3.utils.utf8ToHex("Cash"), oracle.address, token.address);

        await factory.createIssuer(bond.address, web3.utils.utf8ToHex("Via_USD"), web3.utils.utf8ToHex("Bond"), oracle.address, token.address);
        await factory.createIssuer(bond.address, web3.utils.utf8ToHex("Via_EUR"), web3.utils.utf8ToHex("Bond"), oracle.address, token.address);
        await factory.createIssuer(bond.address, web3.utils.utf8ToHex("Via_INR"), web3.utils.utf8ToHex("Bond"), oracle.address, token.address);

        for (let i = 0; i < 6; i++) {
            var factoryTokenAddress = await factory.tokens(i);
            console.log("Token address:", factoryTokenAddress);
            console.log("Token name:", web3.utils.hexToUtf8(await factory.getName(factoryTokenAddress)));
            console.log("Token type:", web3.utils.hexToUtf8(await factory.getType(factoryTokenAddress)));
            console.log();
        }       
    });
    
}




