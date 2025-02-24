// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IUrlsFactory} from "./interfaces/IUrlsFactory.sol";
import {Urls} from "./Urls.sol";

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
// -----------!!!              wow wow wow             !!!----------------
// -----------------------------------------------------------------------

contract UrlsFactoryImpl is
    IUrlsFactory,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using ECDSA for bytes32;

    address public immutable tokenImplementation;
    address public immutable bondingCurve;
    uint256 public deployFee;
    address public feeSigner;

    event FeeSignerUpdated(
        address indexed previousSigner,
        address indexed newSigner
    );

    constructor(
        address _tokenImplementation,
        address _bondingCurve
    ) initializer {
        tokenImplementation = _tokenImplementation;
        bondingCurve = _bondingCurve;
    }

    /// @notice Updates the address that can sign fee-bypass messages
    /// @param _newSigner The new signer address
    function updateFeeSigner(address _newSigner) external onlyOwner {
        address oldSigner = feeSigner;
        feeSigner = _newSigner;
        emit FeeSignerUpdated(oldSigner, _newSigner);
    }

    /// @notice Verifies if a signature is valid for fee bypass
    /// @param _tokenCreator The address of the token creator
    /// @param _tokenURI The token URI
    /// @param signature The signature to verify
    function _verifyFeeBypass(
        address _tokenCreator,
        string memory _tokenURI,
        bytes32 messageHash,
        bytes memory signature
    ) internal returns (bool) {
        if (feeSigner == address(0)) return false;

        bytes32 prefixedHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        address recoveredSigner = ECDSA.recover(prefixedHash, signature);

        if (recoveredSigner == feeSigner) return true;
        return false;
    }

    /// @notice Creates a Urls token with bonding curve mechanics that graduates to Uniswap V3
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
    ) external payable nonReentrant returns (address) {
        bool isFeeBypass = _verifyFeeBypass(
            _tokenCreator,
            _tokenURI,
            _messageHash,
            _signature
        );

        if (!isFeeBypass) {
            require(msg.value >= deployFee, "Insufficient ETH sent");
        }

        bytes32 salt = _generateSalt(_tokenCreator, _tokenURI);

        Urls token = Urls(
            payable(Clones.cloneDeterministic(tokenImplementation, salt))
        );

        uint256 valueToSend = 0 ether;

        if (!isFeeBypass) {
            valueToSend = msg.value - deployFee;
        }

        token.initialize{value: valueToSend}(
            _tokenCreator,
            _platformReferrer,
            address(0),
            bondingCurve,
            _tokenURI,
            _name,
            _symbol
        );

        emit UrlsTokenCreated(
            address(this),
            _tokenCreator,
            _platformReferrer,
            token.protocolFeeRecipient(),
            bondingCurve,
            _tokenURI,
            _name,
            _symbol,
            address(token),
            token.poolAddress()
        );

        return address(token);
    }

    /// @dev Generates a unique salt for deterministic deployment
    function _generateSalt(
        address _tokenCreator,
        string memory _tokenURI
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    _tokenCreator,
                    keccak256(abi.encodePacked(_tokenURI)),
                    block.coinbase,
                    block.number,
                    block.prevrandao,
                    block.timestamp,
                    tx.gasprice,
                    tx.origin
                )
            );
    }

    /**
     * @notice Returns the current deployment fee
     * @return The current deployment fee in wei
     */
    function getDeployFee() external view returns (uint256) {
        return deployFee;
    }

    /**
     * @notice Updates the fee required to deploy new Urls tokens
     * @dev Can only be called by the contract owner
     * @param _newFee The new fee amount in wei
     * @param _reason A string description explaining the reason for the fee update
     * @custom:access Restricted to contract owner (onlyOwner)
     * @custom:events Emits DeployFeeUpdated event with previous fee, new fee, and reason
     */
    function updateDeployFee(
        uint256 _newFee,
        string memory _reason
    ) external onlyOwner {
        uint256 previousFee = deployFee;
        deployFee = _newFee;
        emit DeployFeeUpdated(msg.sender, previousFee, _newFee, _reason);
    }

    /// @notice Initializes the factory proxy contract
    /// @param _owner Address of the contract owner
    /// @dev Can only be called once due to initializer modifier
    function initialize(address _owner) external initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
        deployFee = 0.000666 ether;
        feeSigner = address(0);
    }

    /// @notice The implementation address of the factory contract
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @dev Authorizes an upgrade to a new implementation
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}

    /// @notice Withdraws all ETH and ERC20 tokens to the caller
    /// @dev Can only be called by the contract owner
    /// @param tokens Array of ERC20 token addresses to withdraw
    function withdraw(
        address[] calldata tokens
    ) external onlyOwner nonReentrant {
        // Handle ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = msg.sender.call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }

        // Handle ERC20 tokens
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ) {
            address token = tokens[i];
            require(token != address(0), "Invalid token address");

            IERC20 erc20 = IERC20(token);
            uint256 balance = erc20.balanceOf(address(this));
            if (balance > 0) {
                require(
                    erc20.transfer(msg.sender, balance),
                    "ERC20 transfer failed"
                );
            }

            unchecked {
                ++i;
            }
        }

        emit Withdrawn(msg.sender, ethBalance, tokens);
    }
}
