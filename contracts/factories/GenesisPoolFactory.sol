// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import '../interfaces/IGenesisPoolFactory.sol';
import '../GenesisPool.sol';
import '../interfaces/IGenesisPool.sol';

contract GenesisPoolFactory is IGenesisPoolFactory, OwnableUpgradeable {

    address public genesisManager;

    mapping(address => address) isGenesisPool;
    address[] public genesisPools;
    address[] public completed;
    address[] public failed;

    event GenesisCreated(address indexed nativeToken, address indexed fundingToken);
    event GenesisManagerChanged(address indexed oldManager, address indexed newManager);

    modifier onlyManager() {
        require(msg.sender == genesisManager);
        _;
    }

    constructor() {}

    function initialize() public initializer {
        __Ownable_init();

        genesisManager = msg.sender;
    }

    function SetGenesisManager(address _genesisManager) external onlyManager {
        emit GenesisManagerChanged(genesisManager, _genesisManager);
        genesisManager = _genesisManager;
    }

    function createGenesisPool(address nativeToken, address fundingToken) external onlyManager returns (address genesisPool) {
        require(nativeToken != address(0), "0x"); 
        require(isGenesisPool[nativeToken] == address(0), "exists");

        address factory = address(this);
        bytes32 salt = keccak256(abi.encodePacked(nativeToken, fundingToken));
        genesisPool = address(new GenesisPool{salt: salt}(factory, genesisManager, nativeToken, fundingToken));

        isGenesisPool[nativeToken] = genesisPool;
        genesisPools.push(genesisPool);

        emit GenesisCreated(nativeToken, fundingToken);
    }
}