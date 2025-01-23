// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../chainlink/AutomationCompatible.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/IVoter.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract EpochControllerV2 is AutomationCompatibleInterface  {

    address public automationRegistry;
    address public minter;
    address public voter;
    event Logger(address indexed addr, uint timestamp,uint blocknbr, string msg);

    constructor() {}


    function checkUpkeep(bytes memory /*checkdata*/) public view override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        upkeepNeeded = true;
        // IMinter(minter).check()
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        // require(msg.sender == automationRegistry, 'cannot execute');
        // (bool upkeepNeeded, ) = checkUpkeep('0');
        // require(upkeepNeeded, "condition not met");
        emit Logger(msg.sender, block.timestamp,block.number, 'performUpkeep called');
        // IVoter(voter).distributeAll();
        // IVoter(voter).distributeFees();
    }

    function setAutomationRegistry(address _automationRegistry) external {
        require(_automationRegistry != address(0));
        automationRegistry = _automationRegistry;
    }

    function setVoter(address _voter) external {
        require(_voter != address(0));
        voter = _voter;
    }

    function setMinter(address _minter ) external {
        require(_minter != address(0));
        minter = _minter;
    }



}