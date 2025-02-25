// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import '../interfaces/IGenesisPoolFactory.sol';
import '../GenesisPool.sol';
import '../interfaces/IGenesisPool.sol';
import '../interfaces/ITokenHandler.sol';

contract GenesisPoolFactory is IGenesisPoolFactory, OwnableUpgradeable {

    address public genesisManager;
    address public tokenHandler;
    address public voter;

    mapping(address => address) public getGenesisPool;
    address[] public genesisPools;

    event GenesisCreated(address indexed nativeToken, address indexed fundingToken);
    event GenesisManagerChanged(address indexed oldManager, address indexed newManager);

    modifier onlyManager() {
        require(msg.sender == genesisManager);
        _;
    }

    constructor() {}

    function initialize(address _tokenHandler, address _voter) public initializer {
        __Ownable_init();

        genesisManager = msg.sender;
        tokenHandler = _tokenHandler;
        voter = _voter;
    }

    function SetGenesisManager(address _genesisManager) external onlyManager {
        emit GenesisManagerChanged(genesisManager, _genesisManager);
        genesisManager = _genesisManager;
    }

    function genesisPoolsLength() external view returns (uint256){
        return genesisPools.length;
    }

    function createGenesisPool(address tokenOwner, address nativeToken, address fundingToken, address auction) external onlyManager returns (address genesisPool) {
        require(nativeToken != address(0), "0x"); 
        require(getGenesisPool[nativeToken] == address(0), "exists");

        address factory = address(this);
        bytes32 salt = keccak256(abi.encodePacked(nativeToken, fundingToken));
        genesisPool = address(new GenesisPool{salt: salt}(factory, genesisManager, tokenHandler, voter, auction, tokenOwner, nativeToken, fundingToken));

        getGenesisPool[nativeToken] = genesisPool;
        genesisPools.push(genesisPool);

        emit GenesisCreated(nativeToken, fundingToken);
    }
}