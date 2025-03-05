// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ITokenHandler {
    function isWhitelisted(address token) external returns (bool);
    function isWhitelistedNFT(uint256 token) external returns (bool);
    function isConnector(address token) external returns (bool);

    function whitelistToken(address _token) external;
    function blacklistToken(address _token) external;

    function whiteListed(uint256 index) external returns (address);
    function connectors(uint256 index) external returns (address);
    function whiteListedTokensLength() external returns (uint256);
    function connectorTokensLength() external returns (uint256);
}