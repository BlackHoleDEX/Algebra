// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ITokenHandler {
    function isWhitelisted(address token) external returns (bool);
    function isWhitelistedNFT(uint256 token) external returns (bool);
    function isConnector(address token) external returns (bool);

    function whitelist(address _token) external;
    function blacklist(address _token) external;
}