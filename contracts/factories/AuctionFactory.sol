// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import '../interfaces/IAuctionFactory.sol';

contract AuctionFactory is IAuctionFactory, OwnableUpgradeable {

    address[] public factories;
    mapping(address => bool) public isFactory;

    event AddFactory(address indexed factory);
    event SetFactory(address indexed old, address indexed latest);

    modifier onlyManager() {
        require(msg.sender == owner());
        _;
    }

    constructor() {}

    function initialize(address _factory) public initializer {
        __Ownable_init();

        isFactory[_factory] = true;
        factories.push(_factory);
    }

     function addFactory(address _factory) external onlyManager {
        require(_factory != address(0), 'addr0');
        require(!isFactory[_factory], 'fact');
        require(_factory.code.length > 0, "!contract");

        factories.push(_factory);
        isFactory[_factory] = true;
        emit AddFactory(_factory);
    }

    function replaceFactory(address _factory, uint256 _pos) external onlyManager {
        require(_factory != address(0), 'addr0');
        require(isFactory[_factory], '!fact');
        address oldPF = factories[_pos];
        isFactory[oldPF] = false;

        factories[_pos] = _factory;
        isFactory[_factory] = true;

        emit SetFactory(oldPF, _factory);
    }

    function removeFactory(uint256 _pos) external onlyManager {
        address oldPF = factories[_pos];
        require(isFactory[oldPF], '!fact');

        factories[_pos] = address(0);
        isFactory[oldPF] = false;

        emit SetFactory(oldPF, address(0));
    }

    function factoriesLength() external view returns (uint256){
        return factories.length;
    }

    function allFactories() external view returns (address[] memory){
        return factories;
    }
}