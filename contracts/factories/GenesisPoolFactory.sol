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

    mapping(address => address[]) public getGenesisPools;
    address[] public genesisPools;

    event GenesisCreated(address indexed nativeToken, address indexed fundingToken);
    event GenesisManagerChanged(address indexed oldManager, address indexed newManager);

    modifier onlyManager() {
        require(msg.sender == genesisManager);
        _;
    }

    constructor() {}

    function initialize(address _tokenHandler) public initializer {
        __Ownable_init();

        genesisManager = msg.sender;
        tokenHandler = _tokenHandler;
    }

    function setGenesisManager(address _genesisManager) external onlyManager {
        emit GenesisManagerChanged(genesisManager, _genesisManager);
        genesisManager = _genesisManager;
    }

    function genesisPoolsLength() external view returns (uint256){
        return genesisPools.length;
    }

    function removeGenesisPool(address nativeToken) external onlyManager {
        for (uint256 i = 0; i < getGenesisPools[nativeToken].length; i++) {
            getGenesisPools[nativeToken][i] = address(0);
        }
    }

    function createGenesisPool(address tokenOwner, address nativeToken, address fundingToken) external onlyManager returns (address genesisPool) {
        require(nativeToken != address(0), "0x"); 
        require(getGenesisPool(nativeToken) == address(0), "exists");

        bytes32 salt = keccak256(abi.encodePacked(nativeToken, fundingToken, genesisPools.length));
        genesisPool = address(new GenesisPool{salt: salt}(genesisManager, tokenHandler, tokenOwner, nativeToken, fundingToken));

        getGenesisPools[nativeToken].push(genesisPool);
        genesisPools.push(genesisPool);

        emit GenesisCreated(nativeToken, fundingToken);
    }

    function getGenesisPool(address nativeToken) public view returns (address) {
        address[] memory pools = getGenesisPools[nativeToken];
        if (pools.length == 0) {
            return address(0);
        }
        if(IGenesisPool(pools[pools.length - 1]).poolStatus() != IGenesisPoolBase.PoolStatus.NOT_QUALIFIED)
            return pools[pools.length - 1];
        return address(0);
    }

}