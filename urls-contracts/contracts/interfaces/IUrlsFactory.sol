// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// -----------------------------------------------------------------------
// ______   _____    ___________     _____                        _____
// \     \  \    \   \          \   |\    \                  _____\    \
//  \    |  |    |    \    /\    \   \\    \                /    / \    |
//   |   |  |    |     |   \_\    |   \\    \              |    |  /___/|
//   |    \_/   /|     |      ___/     \|    | ______   ____\    \ |   ||
//   |\         \|     |      \  ____   |    |/      \ /    /\    \|___|/
//   | \         \__  /     /\ \/    \  /            ||    |/ \    \
//    \ \_____/\    \/_____/ |\______| /_____/\_____/||\____\ /____/|
//     \ |    |/___/||     | | |     ||      | |    ||| |   ||    | |
//      \|____|   | ||_____|/ \|_____||______|/|____|/ \|___||____|/
//            |___|/
// -----------------------------------------------------------------------

interface IUrlsFactory {
    /// @notice Emitted when a new Urls token is created
    /// @param factoryAddress The address of the factory that created the token
    /// @param tokenCreator The address of the creator of the token
    /// @param platformReferrer The address of the platform referrer
    /// @param protocolFeeRecipient The address of the protocol fee recipient
    /// @param bondingCurve The address of the bonding curve
    /// @param tokenURI The URI of the token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param tokenAddress The address of the token
    /// @param poolAddress The address of the pool
    event UrlsTokenCreated(
        address indexed factoryAddress,
        address indexed tokenCreator,
        address platformReferrer,
        address protocolFeeRecipient,
        address bondingCurve,
        string tokenURI,
        string name,
        string symbol,
        address tokenAddress,
        address poolAddress
    );

    /// @notice Emitted when the deployment fee is updated
    /// @param updatedBy The address of the account that updated the fee
    /// @param previousFee The fee amount before the update
    /// @param newFee The fee amount after the update
    /// @param reason The reason provided for updating the fee
    event DeployFeeUpdated(
        address indexed updatedBy,
        uint256 previousFee,
        uint256 newFee,
        string reason
    );

    /// @notice Emitted when assets are withdrawn
    /// @param to Address that received the assets
    /// @param ethAmount Amount of ETH withdrawn
    /// @param tokens Array of ERC20 token addresses that were withdrawn
    event Withdrawn(address indexed to, uint256 ethAmount, address[] tokens);

    /// @notice Deploys a Urls ERC20 token
    /// @param _tokenCreator The address of the token creator
    /// @param _platformReferrer The address of the platform referrer
    /// @param _tokenURI The ERC20z token URI
    /// @param _name The ERC20 token name
    /// @param _symbol The ERC20 token symbol
    /// @param _messageHash The message hash
    /// @param _signature Optional signature for fee bypass
    function deploy(
        address _tokenCreator,
        address _platformReferrer,
        string memory _tokenURI,
        string memory _name,
        string memory _symbol,
        bytes32 _messageHash,
        bytes memory _signature
    ) external payable returns (address);

    /// @notice Updates the fee required to deploy new Urls tokens
    /// @dev Can only be called by the contract owner
    /// @param _newFee The new fee amount in wei
    /// @param _reason A string description explaining the reason for the fee update
    /// @custom:access Restricted to contract owner (onlyOwner)
    /// @custom:events Emits DeployFeeUpdated event with previous fee, new fee, and reason
    function updateDeployFee(uint256 _newFee, string memory _reason) external;

    /// @notice Returns the current deployment fee
    /// @return The current deployment fee in wei
    function getDeployFee() external view returns (uint256);

    /// @notice Withdraws all ETH and ERC20 tokens to the caller
    /// @dev Can only be called by the contract owner
    /// @param tokens Array of ERC20 token addresses to withdraw
    function withdraw(address[] calldata tokens) external;
}
