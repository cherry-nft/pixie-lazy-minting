// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Urls} from "../../contracts/Urls.sol";
import {BondingCurve} from "../../contracts/BondingCurve.sol";
import {IUrls} from "../../contracts/interfaces/IUrls.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IWETH} from "../../contracts/interfaces/IWETH.sol";
import "forge-std/console.sol";

contract UrlsTest is Test {
    Urls public urlsImpl;
    IUrls public urls;
    IERC20 public urlsErc20;
    BondingCurve public bondingCurve;
    address public mockPool;

    address public constant WETH = address(0x1);
    address public constant NFT_POS_MGR = address(0x2);
    address public constant SWAP_ROUTER = address(0x3);
    address public constant PROTOCOL_REWARDS = address(0x4);
    address public constant PROTOCOL_FEE_RECIPIENT = address(0x5);
    address public constant ORIGIN_FEE_RECIPIENT = address(0x6);

    address public constant TOKEN_CREATOR = address(0x100);
    address public constant PLATFORM_REFERRER = address(0x101);
    address public constant BUYER = address(0x102);

    uint256 public constant MIN_ORDER_SIZE = 0.0000001 ether;
    uint256 public constant PRIMARY_MARKET_SUPPLY = 800_000_000e18;
    uint256 public constant SECONDARY_MARKET_SUPPLY = 200_000_000e18;
    uint256 public constant TOTAL_FEE_BPS = 333; // 3.33%

    uint160 public constant POOL_SQRT_PRICE_X96_WETH_0 =
        400950665883918763141200546267337;

    uint256 internal constant TEST_BUY_AMOUNT = 0.1 ether;

    event UrlsTokenBuy(
        address indexed buyer,
        address indexed recipient,
        address indexed orderReferrer,
        uint256 totalEth,
        uint256 ethFee,
        uint256 ethSold,
        uint256 tokensBought,
        uint256 buyerTokenBalance,
        string comment,
        uint256 totalSupply,
        IUrls.MarketType marketType
    );

    event UrlsTokenFees(
        address indexed tokenCreator,
        address indexed platformReferrer,
        address indexed orderReferrer,
        address originFeeRecipient,
        address protocolFeeRecipient,
        uint256 tokenCreatorFee,
        uint256 platformReferrerFee,
        uint256 orderReferrerFee,
        uint256 originFee,
        uint256 protocolFee
    );

    event UrlsMarketGraduated(
        address indexed tokenAddress,
        address indexed poolAddress,
        uint256 totalEthLiquidity,
        uint256 totalTokenLiquidity,
        uint256 lpPositionId,
        IUrls.MarketType marketType
    );

    function setUp() public {
        // Deploy bonding curve
        bondingCurve = new BondingCurve();

        // Create mock pool address
        mockPool = address(0x999);

        // Setup mock contracts
        _setupWethMocks();
        _setupPoolMocks();
        _setupProtocolRewardsMocks();
        _setupNftPositionManagerMocks();
        _setupTokenMocks();

        // Deploy implementation contract
        urlsImpl = new Urls(
            PROTOCOL_FEE_RECIPIENT,
            ORIGIN_FEE_RECIPIENT,
            PROTOCOL_REWARDS,
            WETH,
            NFT_POS_MGR,
            SWAP_ROUTER
        );

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Urls.initialize.selector,
            TOKEN_CREATOR,
            PLATFORM_REFERRER,
            ORIGIN_FEE_RECIPIENT,
            address(bondingCurve),
            "test-uri",
            "Test Token",
            "TEST"
        );

        // Deploy proxy pointing to implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(urlsImpl), initData);

        // Get interfaces pointing to proxy
        urls = IUrls(payable(address(proxy)));
        urlsErc20 = IERC20(address(proxy));

        // Update NFT position manager mock with actual urls address
        _updateNftPositionManagerMocks(address(urls));
    }

    function _setupWethMocks() internal {
        // Mock WETH deposit
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(bytes4(keccak256("deposit()"))),
            abi.encode()
        );

        // Mock WETH withdraw
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)"))),
            abi.encode()
        );

        // Mock WETH transfer
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        // Mock WETH transferFrom
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );

        // Mock WETH approve
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock WETH allowance
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.allowance.selector),
            abi.encode(0)
        );

        // Mock WETH balanceOf
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(1000 ether)
        );
    }

    function _setupPoolMocks() internal {
        // Mock pool slot0 call
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(bytes4(keccak256("slot0()"))),
            abi.encode(400950665883918763141200546267337, 0, 0, 0, 0, 0, false)
        );

        // Mock pool swap call
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(
                bytes4(keccak256("swap(address,bool,int256,uint160,bytes)"))
            ),
            abi.encode(0, 0)
        );

        // Mock pool mint call
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(
                bytes4(keccak256("mint(address,int24,int24,uint128,bytes)"))
            ),
            abi.encode(0, 0, 0)
        );
    }

    function _setupProtocolRewardsMocks() internal {
        // Mock protocol rewards depositBatch
        vm.mockCall(
            PROTOCOL_REWARDS,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "depositBatch(address[],uint256[],bytes4[],bytes)"
                    )
                )
            ),
            abi.encode()
        );
    }

    function _setupNftPositionManagerMocks() internal {
        // Mock NFT position manager createAndInitializePoolIfNecessary
        vm.mockCall(
            NFT_POS_MGR,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "createAndInitializePoolIfNecessary(address,address,uint24,uint160)"
                    )
                )
            ),
            abi.encode(mockPool)
        );

        // Mock NFT position manager mint
        vm.mockCall(
            NFT_POS_MGR,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))"
                    )
                )
            ),
            abi.encode(1, 0, 0, 0)
        );
    }

    function _updateNftPositionManagerMocks(address urlsAddress) internal {
        // Update NFT position manager mock with actual urls address
        vm.mockCall(
            NFT_POS_MGR,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "createAndInitializePoolIfNecessary(address,address,uint24,uint160)"
                    )
                ),
                WETH,
                urlsAddress,
                500,
                400950665883918763141200546267337
            ),
            abi.encode(mockPool)
        );
    }

    function _setupTokenMocks() internal {
        // Mock token approve calls
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock token transfer calls
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        // Mock token transferFrom calls
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
    }

    function _mockBondingCurveForGraduation() internal {
        // Mock getEthBuyQuote to return PRIMARY_MARKET_SUPPLY exactly
        vm.mockCall(
            address(bondingCurve),
            abi.encodeWithSelector(
                bytes4(keccak256("getEthBuyQuote(uint256,uint256)"))
            ),
            abi.encode(PRIMARY_MARKET_SUPPLY)
        );

        // Mock getTokenBuyQuote to return the exact buyAmount
        vm.mockCall(
            address(bondingCurve),
            abi.encodeWithSelector(
                bytes4(keccak256("getTokenBuyQuote(uint256,uint256)"))
            ),
            abi.encode(TEST_BUY_AMOUNT)
        );
    }

    function _mockBondingCurveForRefund() internal {
        uint256 requiredAmount = 1000 ether;

        // Mock initial getEthBuyQuote to return more than PRIMARY_MARKET_SUPPLY
        vm.mockCall(
            address(bondingCurve),
            abi.encodeWithSelector(
                bytes4(keccak256("getEthBuyQuote(uint256,uint256)"))
            ),
            abi.encode(PRIMARY_MARKET_SUPPLY + 1e18)
        );

        // Mock getTokenBuyQuote for the recalculation
        vm.mockCall(
            address(bondingCurve),
            abi.encodeWithSelector(
                bytes4(keccak256("getTokenBuyQuote(uint256,uint256)"))
            ),
            abi.encode(requiredAmount)
        );
    }

    function test_InitialState() public view {
        IUrls.MarketState memory state = urls.state();
        assert(
            uint8(state.marketType) == uint8(IUrls.MarketType.BONDING_CURVE)
        );
        assert(urls.tokenCreator() == TOKEN_CREATOR);
        assert(urls.platformReferrer() == PLATFORM_REFERRER);
        assert(urlsErc20.totalSupply() == 0);
    }

    function test_MinimumBuyAmount() public {
        vm.expectRevert();
        vm.prank(BUYER);
        urls.buy{value: MIN_ORDER_SIZE - 1}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );
    }

    function test_BasicMint() public {
        uint256 buyAmount = 1 ether;

        vm.deal(BUYER, buyAmount);
        vm.prank(BUYER);
        uint256 tokenAmount = urls.buy{value: buyAmount}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        assertGt(tokenAmount, 0);
        assertEq(urlsErc20.balanceOf(BUYER), tokenAmount);
        assertEq(urlsErc20.totalSupply(), tokenAmount);
    }

    function test_MintWithReferrer() public {
        uint256 buyAmount = 1 ether;
        address referrer = address(0x999);

        vm.deal(BUYER, buyAmount);
        vm.prank(BUYER);
        uint256 tokenAmount = urls.buy{value: buyAmount}(
            BUYER,
            BUYER,
            referrer,
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        assertGt(tokenAmount, 0);
        assertEq(urlsErc20.balanceOf(BUYER), tokenAmount);
    }

    function test_MintToOtherRecipient() public {
        uint256 buyAmount = 1 ether;
        address recipient = address(0x888);

        vm.deal(BUYER, buyAmount);
        vm.prank(BUYER);
        uint256 tokenAmount = urls.buy{value: buyAmount}(
            recipient,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        assertGt(tokenAmount, 0);
        assertEq(urlsErc20.balanceOf(recipient), tokenAmount);
        assertEq(urlsErc20.balanceOf(BUYER), 0);
    }

    function test_RevertOnWrongMarketType() public {
        vm.expectRevert();
        vm.prank(BUYER);
        urls.buy{value: 1 ether}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.UNISWAP_POOL,
            0,
            0
        );
    }

    function test_RevertOnZeroRecipient() public {
        vm.expectRevert();
        vm.prank(BUYER);
        urls.buy{value: 1 ether}(
            address(0),
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );
    }

    function test_SlippageProtection() public {
        uint256 buyAmount = 1 ether;
        uint256 minTokens = type(uint256).max; // Set to max uint256 to ensure slippage

        vm.deal(BUYER, buyAmount);
        vm.expectRevert();
        vm.prank(BUYER);
        urls.buy{value: buyAmount}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            minTokens,
            0
        );
    }

    function test_FeeCalculation() public {
        uint256 buyAmount = 1 ether;

        vm.deal(BUYER, buyAmount);
        vm.expectEmit(true, true, true, true);
        emit UrlsTokenFees(
            TOKEN_CREATOR,
            PLATFORM_REFERRER,
            PROTOCOL_FEE_RECIPIENT,
            ORIGIN_FEE_RECIPIENT,
            PROTOCOL_FEE_RECIPIENT,
            (buyAmount * TOTAL_FEE_BPS * 5000) / (10000 * 10000),
            (buyAmount * TOTAL_FEE_BPS * 1000) / (10000 * 10000),
            (buyAmount * TOTAL_FEE_BPS * 1000) / (10000 * 10000),
            (buyAmount * TOTAL_FEE_BPS * 1000) / (10000 * 10000),
            (buyAmount * TOTAL_FEE_BPS * 2000) / (10000 * 10000)
        );

        vm.prank(BUYER);
        urls.buy{value: buyAmount}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );
    }

    function test_MarketGraduation() public {
        uint256 fee = (TEST_BUY_AMOUNT * TOTAL_FEE_BPS) / 10000; // 3.33% fee
        uint256 ethLiquidity = TEST_BUY_AMOUNT - fee;

        _mockBondingCurveForGraduation();

        // Mock token approvals for graduation
        vm.mockCall(
            address(urls),
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock WETH deposit for graduation
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(bytes4(keccak256("deposit()"))),
            abi.encode()
        );

        // Mock WETH approve for graduation
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock NFT position manager mint for graduation
        vm.mockCall(
            NFT_POS_MGR,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))"
                    )
                )
            ),
            abi.encode(1, ethLiquidity, 0, 0)
        );

        // Mock pool slot0 call
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(bytes4(keccak256("slot0()"))),
            abi.encode(POOL_SQRT_PRICE_X96_WETH_0, 0, 0, 0, 0, 0, false)
        );

        // Mock pool swap call
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(
                bytes4(keccak256("swap(address,bool,int256,uint160,bytes)"))
            ),
            abi.encode(0, 0)
        );

        vm.deal(BUYER, TEST_BUY_AMOUNT);
        vm.expectEmit(true, true, false, true);
        emit UrlsMarketGraduated(
            address(urls),
            mockPool,
            ethLiquidity,
            SECONDARY_MARKET_SUPPLY,
            1,
            IUrls.MarketType.UNISWAP_POOL
        );

        vm.prank(BUYER);
        urls.buy{value: TEST_BUY_AMOUNT}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        // Verify market graduated
        IUrls.MarketState memory state = urls.state();
        assertEq(uint8(state.marketType), uint8(IUrls.MarketType.UNISWAP_POOL));
        assertEq(state.marketAddress, mockPool);
    }
}
