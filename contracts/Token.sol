// (c) Kallol Borah, 2020
// Implements token issued by Bond issuer. Can be reused by any financial product issuer

pragma solidity >=0.5.0 <0.7.0;

import "./erc/ERC20.sol";
import "./ViaBond.sol";
import "./ViaToken.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "./utilities/StringUtils.sol";

contract Token is ViaToken, ERC20, Initializable, Ownable {

    using stringutils for *;

    //Via token attributes (eg, name : Via-USD, product : ViaBond, symbol : bond identifier)
    string public name;
    bytes32 public product;
    string public symbol;
    address payable issuer;

    //initiliaze proxies
    function initialize(string memory _name, address payable _owner, bytes32 _product, string memory _symbol) public initializer{
        Ownable.initialize(_owner);
        issuer = _owner;
        name = _name;
        symbol = _symbol;
        product = _product;
        decimals = 2;
    }

    function addTotalSupply(bytes16 amount) external{
        require(issuer==msg.sender);
        //adjust total supply
        totalSupply_ = ABDKMathQuad.add(totalSupply_, amount);
    }

    function reduceSupply(bytes16 amount) external{        
        require(issuer==msg.sender);
        totalSupply_ = ABDKMathQuad.sub(totalSupply_, amount);
    }

    function addBalance(address party, bytes16 amount) external{
        require(issuer==msg.sender);
        //add via to this contract's balance first (ie issue them first)
        balances[party] = ABDKMathQuad.add(balances[party], amount);
    }

    function reduceBalance(address party, bytes16 amount) external{
        require(issuer==msg.sender);
        balances[party] = ABDKMathQuad.sub(balances[party], amount);
    }

    function transferFrom(address sender, address receiver, uint256 tokens) public returns (bool){
        //ensure sender has enough tokens in balance before transferring or redeeming them
        require(ABDKMathQuad.cmp(balances[sender],ABDKMathQuad.fromUInt(tokens))==1 ||
                ABDKMathQuad.cmp(balances[sender],ABDKMathQuad.fromUInt(tokens))==0);
        if(ViaBond(issuer).transferFoward(symbol.stringToBytes32(), address(this), sender, receiver, tokens))
            return true;
        else
            return false;
    }

    function transferToken(address sender, address receiver, uint256 tokens) external returns (bool){
        require(issuer==msg.sender);
        //owner should have more tokens than being transferred
        if(ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), balances[sender])==-1 || ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), balances[sender])==0){
            //sending contract should be allowed by token owner to make this transfer
            //require(ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), allowed[sender][msg.sender])==-1 || ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), allowed[sender][msg.sender])==0);
            balances[sender] = ABDKMathQuad.sub(balances[sender], ABDKMathQuad.fromUInt(tokens));
            //allowed[sender][msg.sender] = ABDKMathQuad.sub(allowed[sender][msg.sender], ABDKMathQuad.fromUInt(tokens));
            balances[receiver] = ABDKMathQuad.add(balances[receiver], ABDKMathQuad.fromUInt(tokens));
            return true;
        }
        return false;
    }   


    function requestTransfer(address receiver, uint tokens) external returns (bool){
        transfer(receiver, tokens);
    }    

}