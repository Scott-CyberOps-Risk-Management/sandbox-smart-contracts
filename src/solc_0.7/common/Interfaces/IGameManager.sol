//SPDX-License-Identifier: MIT
pragma solidity 0.7.1;

interface IGameManager {
    function createGame(
        address from,
        address to,
        uint256[] memory assetIds,
        uint256[] memory values,
        address[] memory editors,
        string memory uri,
        uint96 randomId
    ) external returns (uint256 gameId);

    function addAssets(
        address from,
        uint256 gameId,
        uint256[] memory assetIds,
        uint256[] memory values,
        string memory uri,
        address editor
    ) external;

    function removeAssets(
        address from,
        uint256 gameId,
        uint256[] memory assetIds,
        uint256[] memory values,
        address to,
        string memory uri,
        address editor
    ) external;
}