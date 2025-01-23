// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../chainlink/AutomationCompatibleInterface.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/IVoter.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EpochController is AutomationCompatibleInterface, OwnableUpgradeable  {

    address public automationRegistry;
    address public minter;
    address public voter;
    event Logger(string addr, uint timestamp,uint blocknbr , bool x1, bool x2, string msg);

    constructor() {}

    function initialize() public initializer {
        __Ownable_init();
        minter = address(0x86069FEb223EE303085a1A505892c9D4BdBEE996);
        voter = address(0x62Ee96e6365ab515Ec647C065c2707d1122d7b26);
        automationRegistry = address(0x02777053d6764996e594c3E88AF1D58D5363a2e6);
    }


    function checkUpkeep(bytes memory /*checkdata*/) public view override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        upkeepNeeded = IMinter(minter).check();
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        // require(msg.sender == automationRegistry || msg.sender == owner(), 'cannot execute');
        // (bool upkeepNeeded, ) = checkUpkeep('0');
        // require(upkeepNeeded, "condition not met");
        string memory sender = Strings.toHexString(msg.sender);
        emit Logger(sender, block.timestamp,block.number, msg.sender == automationRegistry, msg.sender == owner(), 'performUpkeep called');
        IVoter(voter).distributeAll();
        IVoter(voter).distributeFees();
    }

    function setAutomationRegistry(address _automationRegistry) external onlyOwner {
        require(_automationRegistry != address(0));
        automationRegistry = _automationRegistry;
    }

    function setVoter(address _voter) external onlyOwner {
        require(_voter != address(0));
        voter = _voter;
    }

    function setMinter(address _minter ) external onlyOwner {
        require(_minter != address(0));
        minter = _minter;
    }



}