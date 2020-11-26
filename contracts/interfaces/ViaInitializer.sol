pragma solidity >=0.5.0 <0.7.0;

// basic initializer function interface for bond, token, and cash contracts
interface ViaInitializer {
    function initialize(bytes32 _name, bytes32 _type, address _owner, address _oracle, address _token) external;
}