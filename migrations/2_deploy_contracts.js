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
    await deployer.link(stringutils, [Bond, Cash, ViaOracle]);

    await deployProxy(ABDKMathQuad, {deployer});
    await deployer.link(ABDKMathQuad,[Cash, Bond, ViaOracle, ERC20, Token]);

    // this contract is not yet upgrade safe, see https://github.com/verified-network/via-issuer/issues/38#issuecomment-731461807 for more information
    // await deployProxy(ViaOracle, {deployer});
    // const oracleInstance = await ViaOracle.deployed();
    // oracleInstance.sendTransaction({from:accounts[0], to: oracleInstance.address, value:  0.25e18})
    await deployer.deploy(ViaOracle, {from: accounts[0], gas:6721975, value: 0.25e18});

    // this contract is not yet upgrade safe, see https://github.com/verified-network/via-issuer/issues/38#issuecomment-731461807 for more information
    // await deployProxy(Cash, {deployer});
    await deployer.deploy(Cash);

    // this contract is not yet upgrade safe, see https://github.com/verified-network/via-issuer/issues/38#issuecomment-731461807 for more information
    // await deployProxy(Bond, {deployer});
    await deployer.deploy(Bond);

    // this contract is not yet upgrade safe, see https://github.com/verified-network/via-issuer/issues/38#issuecomment-731461807 for more information
    // await deployProxy(Token, {deployer});
    await deployer.deploy(Token);

    /* // this contract is not yet upgrade safe, see https://github.com/verified-network/via-issuer/issues/38#issuecomment-731461807 for more information
    await deployProxy(Factory, {deployer}).then(async () => {
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
    });*/
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






