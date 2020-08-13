// (c) Kallol Borah, 2020
// Implementation of the Via zero coupon bond.

pragma solidity >=0.5.0 <0.7.0;

import "./erc/ERC20.sol";
import "./oraclize/ViaRate.sol";
import "./oraclize/EthToUSD.sol";
import "abdk-libraries-solidity/ABDKMathQuad.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Factory.sol";

contract Bond is ERC20, Initializable, Ownable {

    //via token factory address
    Factory private factory;

    //name of Via token (eg, Via-USD%)
    bytes32 public name;
    bytes32 public symbol;

    //ether balances held by this issuer against which via bond tokens are issued
    mapping(address => bytes16) private ethbalances;

    //a Via bond has some value, corresponds to a fiat currency
    //has a purchaser and seller that have agreed to a zero coupon rate which is the start price of the bond
    //and a tenure in unix timestamps of seconds counted from 1970-01-01. Via bonds are of one year tenure.
    struct loan{
        bytes32 currency;
        bytes16 faceValue;
        bytes16 price;
        bytes16 collateralAmount;
        bytes32 collateralCurrency;
        uint256 timeOfIssue;
        bytes16 tenure;
    }

    //mapping borrower (address) to loans. Borrower is the seller of the bond, Lender is the buyer of the bond.
    mapping(address => loan[]) public loans;

    //for Oraclize
    bytes32 EthXid;
    bytes32 ViaXid;
    bytes32 ViaRateId;
    
    struct conversion{
        bytes32 operation;
        address party;
        bytes16 amount;
        bytes32 currency;
        bytes32 EthXid;
        bytes16 EthXvalue;
        bytes32 name;
        bytes16 ViaXvalue;
        bytes32 ViaRateId;
        bytes16 ViaRateValue;
    }

    mapping(bytes32 => conversion) private conversionQ;

    bytes32[] private conversions;

    //events to capture and report to Via oracle
    event ViaBondIssued(bytes32 currency, uint value, uint price, uint tenure);
    event ViaBondRedeemed(bytes32 currency, uint value, uint price, uint tenure);

    //initiliaze proxies
    function initialize(bytes32 _name, address _owner) public {
        Ownable.initialize(_owner);
        factory = Factory(_owner);
        name = _name;
        symbol = _name;
    }

    //handling pay in of ether for issue of via bond tokens
    function() external payable{
        //ether paid in
        require(msg.value !=0);
        //issue via bond tokens
        issue(ABDKMathQuad.fromUInt(msg.value), msg.sender, "ether", address(this));
    }

    //overriding this function of ERC20 standard
    function transferFrom(address sender, address receiver, uint256 tokens) public returns (bool){
        //check if tokens are being transferred to this bond contract
        if(receiver == address(this)){
            //if token name is the same, this transfer has to be redeemed
            if(Bond(address(msg.sender)).name()==name){
                if(redeem(ABDKMathQuad.fromUInt(tokens), sender, name))
                    return true;
                else
                    return false;
            }
            //else request issue of bond tokens generated by this contract
            else{
                //issue only if paid in tokens are cash tokens, since bond tokens can't be paid to issue bond token
                for(uint256 p=0; p<factory.getTokenCount(); p++){
                    address viaAddress = factory.tokens(p);
                    if(factory.getName(viaAddress) == Bond(address(msg.sender)).name() &&
                        factory.getType(viaAddress) != "ViaBond"){
                        issue(ABDKMathQuad.fromUInt(tokens), sender, Bond(address(msg.sender)).name(), viaAddress);
                        return true;
                    }
                }
                return false;
            }
        }
        else {
            //tokens are being sent to a user account
            //owner should have more tokens than being transferred
            require(ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), balances[sender])==-1 || ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), balances[sender])==0);
            //sending contract should be allowed by token owner to make this transfer
            require(ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), allowed[sender][msg.sender])==-1 || ABDKMathQuad.cmp(ABDKMathQuad.fromUInt(tokens), allowed[sender][msg.sender])==0);
            balances[sender] = ABDKMathQuad.sub(balances[sender], ABDKMathQuad.fromUInt(tokens));
            allowed[sender][msg.sender] = ABDKMathQuad.sub(allowed[sender][msg.sender], ABDKMathQuad.fromUInt(tokens));
            balances[receiver] = ABDKMathQuad.add(balances[receiver], ABDKMathQuad.fromUInt(tokens));
            emit Transfer(sender, receiver, tokens);
            return true;
        }
    }

    //requesting issue of Via bonds to buyer for amount of paid in currency as collateral
    function issue(bytes16 amount, address buyer, bytes32 currency, address balanceHolder) private returns(bool){
        //ensure that brought amount is not zero
        require(amount != 0);
        //adds paid in amount to the paid in currency's cash balance
        if(currency!="ether")
            if(!Cash(address(uint160(balanceHolder))).addToBalance(amount, buyer))
                return false;
        else
            //if ether is paid in, add balance to this bond's ether balances
            ethbalances[balanceHolder] = ABDKMathQuad.add(ethbalances[balanceHolder], amount);
        //call Via Oracle to fetch data for bond pricing
        if(currency=="ether"){
            if(name!="Via-USD"){
                EthXid = "9101112"; //only for testing
                ViaXid = "1234"; //only for testing
                conversionQ[ViaXid] = conversion("issue", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), name, ABDKMathQuad.fromUInt(0), ViaRateId, ABDKMathQuad.fromUInt(0));
                conversions.push(ViaXid);
                new EthToUSD().update("Bond", address(this));
                new ViaRate().requestPost(abi.encodePacked("Via_USD_to_", name),"ver","Bond", address(this));
            }
            else{
                EthXid = "9101112"; //only for testing
                conversionQ[EthXid] = conversion("issue", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), name, ABDKMathQuad.fromUInt(0), ViaRateId, ABDKMathQuad.fromUInt(0));
                conversions.push(EthXid);
                new EthToUSD().update("Bond", address(this));
            }
        }
        else{
            ViaXid = "1234"; //only for testing
            new ViaRate().requestPost(abi.encodePacked(currency, "_to_", name),"er","Bond", address(this));
            if(currency!="Via-USD"){
                ViaRateId = "5678"; //only for testing
                conversionQ[ViaXid] = conversion("issue", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), name, ABDKMathQuad.fromUInt(0), ViaRateId, ABDKMathQuad.fromUInt(0));
                conversions.push(ViaXid);
                new ViaRate().requestPost(abi.encodePacked("Via_USD_to_", currency), "ir","Bond",address(this));
            }
            else{
                ViaRateId = "5678"; //only for testing
                conversionQ[ViaXid] = conversion("issue", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), name, ABDKMathQuad.fromUInt(0), ViaRateId, ABDKMathQuad.fromUInt(0));
                conversions.push(ViaXid);
                new ViaRate().requestPost("USD", "ir","Bond",address(this));
            }
        }
        //conversionQ[ViaXid] = conversion("issue", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), name, ABDKMathQuad.fromUInt(0), ViaRateId, ABDKMathQuad.fromUInt(0));
        //conversions.push(ViaXid);
        return true;
        //find face value of bond in via denomination
        //faceValue = convertToVia(amount, currency);
        //find price of via bonds to transfer after applying exchange rate
        //viaBondPrice = getBondValueToIssue(faceValue, currency, 1);
        
    }

    //requesting redemption of Via bonds and transfer of ether or via cash collateral to borrower 
    function redeem(bytes16 amount, address buyer, bytes32 tokenName) private returns(bool){
        bool found = false;
        //ensure that sold amount is not zero
        if(amount != 0){
            //find currency that buyer had deposited earlier
            bytes32 currency;
            for(uint256 p=0; p<loans[buyer].length; p++){
                if(loans[buyer][p].currency == tokenName){
                    currency = loans[buyer][p].currency;
                    found = true;
                }
            }
            if(found){
                //call Via oracle
                if(currency=="ether"){
                    EthXid = "9101112"; //only for testing
                    new EthToUSD().update("Bond", address(this));
                    ViaXid = "3456"; //only for testing
                    conversionQ[ViaXid] = conversion("redeem", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), tokenName, ABDKMathQuad.fromUInt(0), ABDKMathQuad.fromUInt(0), ABDKMathQuad.fromUInt(0));
                    conversions.push(ViaXid);
                    new ViaRate().requestPost(abi.encodePacked(tokenName, "_to_Via_USD"),"ver","Bond", address(this));
                }
                else{
                    ViaXid = "1234"; //only for testing
                    conversionQ[ViaXid] = conversion("redeem", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), tokenName, ABDKMathQuad.fromUInt(0), ABDKMathQuad.fromUInt(0), ABDKMathQuad.fromUInt(0));
                    conversions.push(ViaXid);
                    new ViaRate().requestPost(abi.encodePacked(tokenName, "_to_", currency),"er","Bond", address(this));
                }
                //conversionQ[ViaXid] = conversion("redeem", buyer, amount, currency, EthXid, ABDKMathQuad.fromUInt(0), name, ABDKMathQuad.fromUInt(0), ABDKMathQuad.fromUInt(0), ABDKMathQuad.fromUInt(0));
                //conversions.push(ViaXid);

                //find redemption amount to transfer 
                //var(redemptionAmount, balanceTenure) = getBondValueToRedeem(amount, currency, buyer);
                //only if the issuer's balance of the deposited currency is more than or equal to amount redeemed
            }
            else
                return found;
        }
        else
            //redemption is complete when amount to redeem becomes zero
            return found;
    }

    //function called back from Oraclize
    function convert(bytes32 txId, bytes16 result, bytes32 rtype) public {
        //check type of result returned
        if(rtype =="ethusd"){
            conversionQ[txId].EthXvalue = result;
        }
        if(rtype == "ir"){
            conversionQ[txId].ViaRateValue = result;
        }
        if(rtype == "er"){
            conversionQ[txId].EthXvalue = result;
        }
        if(rtype == "ver"){
            conversionQ[txId].ViaXvalue = result;
        }
        //check if bond needs to be issued or redeemed
        if(conversionQ[txId].operation=="issue"){
            if(rtype == "ethusd" || rtype == "ver"){
                if(ABDKMathQuad.cmp(conversionQ[txId].EthXvalue, ABDKMathQuad.fromUInt(0))!=0 &&
                    ABDKMathQuad.cmp(conversionQ[txId].ViaXvalue, ABDKMathQuad.fromUInt(0))!=0){
                    bytes16 faceValue = convertToVia(conversionQ[txId].amount, conversionQ[txId].currency,conversionQ[txId].EthXvalue,conversionQ[txId].ViaXvalue);
                    bytes16 viaBondPrice = getBondValueToIssue(faceValue, conversionQ[txId].currency, ABDKMathQuad.fromUInt(1), conversionQ[txId].EthXvalue, conversionQ[txId].ViaXvalue);
                    finallyIssue(viaBondPrice, faceValue, txId);
                }
            }
            else if(rtype == "er" || rtype =="ir"){
                if(ABDKMathQuad.cmp(conversionQ[txId].EthXvalue, ABDKMathQuad.fromUInt(0))!=0 && ABDKMathQuad.cmp(conversionQ[txId].ViaRateValue, ABDKMathQuad.fromUInt(0))!=0){
                    bytes16 faceValue = convertToVia(conversionQ[txId].amount, conversionQ[txId].currency,conversionQ[txId].EthXvalue,conversionQ[txId].ViaXvalue);
                    bytes16 viaBondPrice = getBondValueToIssue(faceValue, conversionQ[txId].currency, ABDKMathQuad.fromUInt(1), conversionQ[txId].EthXvalue, conversionQ[txId].ViaXvalue);
                    finallyIssue(viaBondPrice, faceValue, txId);
                }
            }
        }
        else if(conversionQ[txId].operation=="redeem"){
            if(rtype == "ethusd" || rtype == "ver"){
                if(ABDKMathQuad.cmp(conversionQ[txId].EthXvalue, ABDKMathQuad.fromUInt(0))!=0 && ABDKMathQuad.cmp(conversionQ[txId].ViaXvalue, ABDKMathQuad.fromUInt(0))!=0){
                    (bytes16 redemptionAmount, bytes16 balanceTenure) = getBondValueToRedeem(conversionQ[txId].amount, conversionQ[txId].currency, conversionQ[txId].party,conversionQ[txId].EthXvalue, result);
                    finallyRedeem(conversionQ[txId].amount, conversionQ[txId].currency, conversionQ[txId].party, redemptionAmount, balanceTenure);
                }
            }
            else if(rtype == "er"){
                if(ABDKMathQuad.cmp(conversionQ[txId].EthXvalue, ABDKMathQuad.fromUInt(0))!=0){
                    (bytes16 redemptionAmount, bytes16 balanceTenure) = getBondValueToRedeem(conversionQ[txId].amount, conversionQ[txId].currency, conversionQ[txId].party,conversionQ[txId].EthXvalue, result);
                    finallyRedeem(conversionQ[txId].amount, conversionQ[txId].currency, conversionQ[txId].party, redemptionAmount, balanceTenure);
                }
            }    
        }
    }

    function finallyIssue(bytes16 viaBondPrice, bytes16 faceValue, bytes32 txId) private {
        //add via bonds to this contract's balance first
        ABDKMathQuad.add(balances[address(this)], viaBondPrice);
        //transfer amount from issuer/sender to borrower
        transfer(conversionQ[txId].party, ABDKMathQuad.toUInt(viaBondPrice));
        //adjust total supply
        totalSupply_ = ABDKMathQuad.add(totalSupply_, viaBondPrice);
        //keep track of issues
        storeIssuedBond(conversionQ[txId].party, name, faceValue, viaBondPrice, conversionQ[txId].amount, conversionQ[txId].currency, now, ABDKMathQuad.fromUInt(1));
        //generate event
        emit ViaBondIssued(name, ABDKMathQuad.toUInt(conversionQ[txId].amount), ABDKMathQuad.toUInt(viaBondPrice), 1);
    }

    function finallyRedeem(bytes16 amount, bytes32 currency, address buyer, bytes16 redemptionAmount, bytes16 balanceTenure) private{
        for(uint256 p=0; p<loans[buyer].length; p++){
            //check if currency in which redemption is to be done was put as collateral at time of issue of bond
            if(loans[buyer][p].collateralCurrency == currency){
                //check if currency in which redemption is to be done has sufficient balance
                if(ABDKMathQuad.cmp(loans[buyer][p].collateralAmount, redemptionAmount)==1 ||
                    ABDKMathQuad.cmp(loans[buyer][p].collateralAmount, redemptionAmount)==0){
                    if(currency=="ether"){
                        ethbalances[address(this)] = ABDKMathQuad.sub(ethbalances[address(this)], redemptionAmount);
                        loans[buyer][p].collateralAmount = ABDKMathQuad.sub(loans[buyer][p].collateralAmount, redemptionAmount);
                        if(loans[buyer][p].collateralAmount==0)
                            delete loans[buyer][p];
                        //adjust total supply
                        totalSupply_ = ABDKMathQuad.sub(totalSupply_, amount);
                        //generate event
                        emit ViaBondRedeemed(currency, ABDKMathQuad.toUInt(amount), ABDKMathQuad.toUInt(redemptionAmount), ABDKMathQuad.toUInt(balanceTenure));
                    }
                    else{
                        for(uint256 q=0; q<factory.getTokenCount(); q++){
                            address viaAddress = factory.tokens(q);
                            if(factory.getName(viaAddress) == currency){
                                if(!Cash(address(uint160(viaAddress))).deductFromBalance(redemptionAmount, buyer)){
                                    loans[buyer][q].collateralAmount = ABDKMathQuad.sub(loans[buyer][q].collateralAmount, redemptionAmount);
                                    if(loans[buyer][q].collateralAmount==0)
                                        delete loans[buyer][q];
                                    //adjust total supply
                                    totalSupply_ = ABDKMathQuad.sub(totalSupply_, amount);
                                    //generate event
                                    emit ViaBondRedeemed(currency, ABDKMathQuad.toUInt(amount), ABDKMathQuad.toUInt(redemptionAmount), ABDKMathQuad.toUInt(balanceTenure));
                                }
                            }
                        }
                    }
                }
                else{
                    if(currency=="ether"){
                        ethbalances[address(this)] = ABDKMathQuad.sub(ethbalances[address(this)], redemptionAmount);
                        bytes16 toRedeem = ABDKMathQuad.sub(redemptionAmount, loans[buyer][p].collateralAmount);
                        bytes16 proportion = ABDKMathQuad.div(loans[buyer][p].collateralAmount, redemptionAmount);
                        delete loans[buyer][p];
                        //adjust total supply
                        totalSupply_ = ABDKMathQuad.sub(totalSupply_, amount);
                        //generate event
                        emit ViaBondRedeemed(currency, ABDKMathQuad.toUInt(amount), ABDKMathQuad.toUInt(redemptionAmount), ABDKMathQuad.toUInt(balanceTenure));
                        redeem(toRedeem, buyer, currency);
                    }
                    else{
                        for(uint256 q=0; q<factory.getTokenCount(); q++){
                            address viaAddress = factory.tokens(q);
                            if(factory.getName(viaAddress) == currency){
                                if(!Cash(address(uint160(viaAddress))).deductFromBalance(redemptionAmount, buyer)){
                                    bytes16 toRedeem = ABDKMathQuad.sub(redemptionAmount, loans[buyer][q].collateralAmount);
                                    bytes16 proportion = ABDKMathQuad.div(loans[buyer][q].collateralAmount, redemptionAmount);
                                    delete loans[buyer][q];
                                    //adjust total supply
                                    totalSupply_ = ABDKMathQuad.sub(totalSupply_, ABDKMathQuad.mul(amount, proportion));
                                    //generate event
                                    emit ViaBondRedeemed(currency, ABDKMathQuad.toUInt(amount), ABDKMathQuad.toUInt(redemptionAmount), ABDKMathQuad.toUInt(balanceTenure));
                                    redeem(toRedeem, buyer, currency);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    //get Via exchange rates from oracle and convert given currency and amount to via cash token
    function convertToVia(bytes16 amount, bytes32 currency, bytes16 ethusd, bytes16 viarate) private returns(bytes16){
        if(currency=="ether"){
            //to first convert amount of ether passed to this function to USD
            bytes16 amountInUSD = ABDKMathQuad.mul(ABDKMathQuad.div(amount, ABDKMathQuad.fromUInt(10^18)), ethusd);
            //to then convert USD to Via-currency if currency of this contract is not USD itself
            if(name!="Via-USD"){
                bytes16 inVia = ABDKMathQuad.mul(amountInUSD, viarate);
                return inVia;
            }
            else{
                return amountInUSD;
            }
        }
        //if currency paid in another via currency
        else{
            bytes16 inVia = viarate;
            return inVia;
        }
    }

    //convert Via-currency (eg, Via-EUR, Via-INR, Via-USD) to Ether or another Via currency
    function convertFromVia(bytes16 amount, bytes32 currency, bytes16 ethusd, bytes16 viarate) private returns(bytes16){
        //if currency to convert from is ether
        if(currency=="ether"){
            bytes16 amountInViaUSD = ABDKMathQuad.mul(amount, viarate);
            bytes16 inEth = ABDKMathQuad.mul(amountInViaUSD, ABDKMathQuad.div(ABDKMathQuad.fromUInt(1),ethusd));
            return inEth;
        }
        //else convert to another via currency
        else{
            return ABDKMathQuad.mul(viarate, amount);
        }
    }

    //uses Oraclize to calculate price of 1 year zero coupon bond in currency and for amount to issue to borrower
    //to do : we need to support bonds with tenure different than the default 1 year. 
    function getBondValueToIssue(bytes16 amount, bytes32 currency, bytes16 tenure, bytes16 ethusd, bytes16 viarate) private returns(bytes16){
        //to first convert amount of ether passed to this function to USD
        bytes16 amountInUSD = ABDKMathQuad.mul(ABDKMathQuad.div(amount, ABDKMathQuad.fromUInt(1000000000000000000)), ethusd);
        //to then get Via interest rates from oracle and calculate zero coupon bond price
        if(currency!="Via-USD"){
            return ABDKMathQuad.div(amountInUSD, ABDKMathQuad.add(ABDKMathQuad.fromUInt(1), viarate))^tenure;
        }
        else{
            return ABDKMathQuad.div(amountInUSD, ABDKMathQuad.add(ABDKMathQuad.fromUInt(1), viarate))^tenure;
        }
    }

    //calculate price of redeeming zero coupon bond in currency and for amount to borrower who may redeem before end of year
    function getBondValueToRedeem(bytes16 _amount, bytes32 _currency, address _borrower, bytes16 ethusd, bytes16 viarate) private returns(bytes16, bytes16){
        //find out if bond is present in list of issued bonds
        bytes16 toRedeem;
        for(uint p=0; p < loans[_borrower].length; p++){
            //if bond is found to be issued
            if(loans[_borrower][p].currency == _currency &&
                (ABDKMathQuad.cmp(loans[_borrower][p].price, _amount)==1 || ABDKMathQuad.cmp(loans[_borrower][p].price, _amount)==0)){
                    uint256 timeOfIssue = loans[_borrower][p].timeOfIssue;
                    //if entire amount is to be redeemed, remove issued bond from store
                    if(ABDKMathQuad.cmp(ABDKMathQuad.sub(loans[_borrower][p].price, _amount), ABDKMathQuad.fromUInt(0))==0){
                        toRedeem = _amount;
                        delete(loans[_borrower][p]);
                    }else{
                        //else, reduce outstanding value of bond
                        loans[_borrower][p].price = ABDKMathQuad.sub(loans[_borrower][p].price, _amount);
                    }
                    return(convertFromVia(toRedeem, _currency, ethusd, viarate), ABDKMathQuad.div(ABDKMathQuad.sub(ABDKMathQuad.fromUInt(now),ABDKMathQuad.fromUInt(timeOfIssue)),ABDKMathQuad.fromUInt(60*60*24*365)));
            }
        }
        return(ABDKMathQuad.fromUInt(0),ABDKMathQuad.fromUInt(0));
    }

    function storeIssuedBond(address _buyer,
                            bytes32 _currency,
                            bytes16 _facevalue,
                            bytes16 _price,
                            bytes16 _collateralAmount,
                            bytes32 _collateralCurrency,
                            uint256 _timeofissue,
                            bytes16 _tenure) private {
        loans[_buyer].push(loan(_currency,_facevalue,_price,_collateralAmount,_collateralCurrency,_timeofissue,_tenure));
    }

}
