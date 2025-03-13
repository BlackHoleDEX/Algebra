// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../chainlink/AutomationCompatibleInterface.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IGenesisPoolManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EpochController is AutomationCompatibleInterface, OwnableUpgradeable  {

    address public automationRegistry;
    address public automationRegistry2;
    address public minter;
    address public voter;
    address public genesisManager;
    event Logger(string addr, uint timestamp,uint blocknbr , bool x1, bool x2, string msg);

    constructor() {}

    function initialize(address _minter, address _voter) public initializer {
        __Ownable_init();
        minter = _minter;
        voter = _voter;
        genesisManager = msg.sender;
        automationRegistry = address(0x02777053d6764996e594c3E88AF1D58D5363a2e6);
        automationRegistry2 = address(0x02777053d6764996e594c3E88AF1D58D5363a2e6);
    }


    function checkUpkeep(bytes memory /*checkdata*/) public view override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        upkeepNeeded = IMinter(minter).check();
        // event fire with upkeepNeeded....
    }

    function checkUpPrekeep(bytes memory /*checkdata*/) public view override returns (bool preUpkeepNeeded, bytes memory /*performData*/) {
        preUpkeepNeeded = IGenesisPoolManager(genesisManager).check();
        // event fire with upkeepNeeded....
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        // event fire msg.sender and automationRegistry
         require(msg.sender == automationRegistry || msg.sender == owner(), 'cannot execute');
         (bool upkeepNeeded, ) = checkUpkeep('0x');
         // event fire with upkeepNeeded..
         require(upkeepNeeded, "condition not met");
        string memory sender = Strings.toHexString(msg.sender);
        emit Logger(sender, block.timestamp,block.number, msg.sender == automationRegistry, msg.sender == owner(), 'performUpkeep called');
        IGenesisPoolManager(genesisManager).checkAtEpochFlip();
        IVoter(voter).distributeAll();
        IVoter(voter).distributeFees();
    }

    function performPreUpkeep(bytes calldata /*performData*/) external override {
        // event fire msg.sender and automationRegistry2
         require(msg.sender == automationRegistry2 || msg.sender == owner(), 'cannot execute');
         (bool preUpkeepNeeded, ) = checkUpPrekeep('0x');
         // event fire with preUpkeepNeeded..
         require(preUpkeepNeeded, "condition not met");
        string memory sender = Strings.toHexString(msg.sender);
        emit Logger(sender, block.timestamp,block.number, msg.sender == automationRegistry2, msg.sender == owner(), 'performUpkeep called');
        IGenesisPoolManager(genesisManager).checkBeforeEpochFlip();
    }

    function setAutomationRegistry(address _automationRegistry) external onlyOwner {
        require(_automationRegistry != address(0));
        automationRegistry = _automationRegistry;
    }

    function setAutomationRegistry2(address _automationRegistry2) external onlyOwner {
        require(_automationRegistry2 != address(0));
        automationRegistry2 = _automationRegistry2;
    }

    function setVoter(address _voter) external onlyOwner {
        require(_voter != address(0));
        voter = _voter;
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0));
        minter = _minter;
    }
    
    function setGenesisManager(address _genesisManager) external onlyOwner {
        require(_genesisManager != address(0));
        genesisManager = _genesisManager;
    }
}