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

contract UrlsFunctionTest is Test {
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
    address public constant SELLER = address(0x103);

    function setUp() public {
        // Deploy bonding curve
        bondingCurve = new BondingCurve();
        mockPool = address(0x999);

        // Setup mock contracts
        _setupMocks();

        // Deploy implementation contract
        urlsImpl = new Urls(
            PROTOCOL_FEE_RECIPIENT,
            ORIGIN_FEE_RECIPIENT,
            PROTOCOL_REWARDS,
            WETH,
            NFT_POS_MGR,
            SWAP_ROUTER
        );

        // Initialize with proxy
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

        ERC1967Proxy proxy = new ERC1967Proxy(address(urlsImpl), initData);
        urls = IUrls(payable(address(proxy)));
        urlsErc20 = IERC20(address(proxy));
    }

    function _setupMocks() internal {
        // Mock WETH
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(bytes4(keccak256("deposit()"))),
            abi.encode()
        );
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)"))),
            abi.encode()
        );
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock Pool
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(bytes4(keccak256("slot0()"))),
            abi.encode(400950665883918763141200546267337, 0, 0, 0, 0, 0, false)
        );

        // Mock NFT Position Manager
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

        // Mock Protocol Rewards
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

    // Test initialize function
    function test_Initialize() public {
        // Test initializing with zero addresses
        vm.expectRevert(IUrls.AddressZero.selector);
        bytes memory initData = abi.encodeWithSelector(
            Urls.initialize.selector,
            address(0), // token creator
            PLATFORM_REFERRER,
            ORIGIN_FEE_RECIPIENT,
            address(bondingCurve),
            "test-uri",
            "Test Token",
            "TEST"
        );
        new ERC1967Proxy(address(urlsImpl), initData);

        // Test initializing with zero bonding curve
        vm.expectRevert(IUrls.AddressZero.selector);
        initData = abi.encodeWithSelector(
            Urls.initialize.selector,
            TOKEN_CREATOR,
            PLATFORM_REFERRER,
            ORIGIN_FEE_RECIPIENT,
            address(0), // bonding curve
            "test-uri",
            "Test Token",
            "TEST"
        );
        new ERC1967Proxy(address(urlsImpl), initData);
    }

    // Test buy function with 4VS for detailed call stack
    function test_Buy_BondingCurve() public {
        uint256 buyAmount = 1 ether;
        vm.deal(BUYER, buyAmount);

        // Test buying with zero recipient
        vm.expectRevert(IUrls.AddressZero.selector);
        vm.prank(BUYER);
        urls.buy{value: buyAmount}(
            address(0),
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        // Test buying with amount below minimum
        vm.expectRevert(IUrls.EthAmountTooSmall.selector);
        vm.prank(BUYER);
        urls.buy{value: 0.00000009 ether}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        // Calculate expected tokens from buy amount (accounting for fee)
        uint256 fee = (buyAmount * 100) / 10000; // 1% fee
        uint256 ethAfterFee = buyAmount - fee;
        uint256 expectedTokens = urls.getEthBuyQuote(ethAfterFee);
        uint256 minTokens = (expectedTokens * 95) / 100; // Allow 5% slippage

        // Test successful buy with slippage protection
        vm.prank(BUYER);
        uint256 tokenAmount = urls.buy{value: buyAmount}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            minTokens,
            0
        );

        assertGt(tokenAmount, minTokens);
        assertEq(urlsErc20.balanceOf(BUYER), tokenAmount);
    }

    // Test sell function with 4VS for detailed call stack
    function test_Sell_BondingCurve() public {
        // First buy some tokens
        uint256 buyAmount = 1 ether;
        vm.deal(BUYER, buyAmount);

        // Calculate expected tokens for initial buy
        uint256 fee = (buyAmount * 100) / 10000; // 1% fee
        uint256 ethAfterFee = buyAmount - fee;
        uint256 expectedTokens = urls.getEthBuyQuote(ethAfterFee);
        uint256 minTokens = (expectedTokens * 95) / 100; // Allow 5% slippage

        vm.prank(BUYER);
        uint256 tokenAmount = urls.buy{value: buyAmount}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            minTokens,
            0
        );

        // Test selling with zero recipient
        vm.expectRevert(IUrls.AddressZero.selector);
        vm.prank(BUYER);
        urls.sell(
            tokenAmount,
            address(0),
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        // Test selling more than balance
        vm.expectRevert(IUrls.InsufficientLiquidity.selector);
        vm.prank(BUYER);
        urls.sell(
            tokenAmount + 1,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            0,
            0
        );

        // Calculate minimum ETH expected from sell
        uint256 expectedEth = urls.getTokenSellQuote(tokenAmount);
        uint256 minEth = (expectedEth * 95) / 100; // Allow 5% slippage

        // Test successful sell with slippage protection
        vm.prank(BUYER);
        uint256 ethReceived = urls.sell(
            tokenAmount,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            minEth,
            0
        );

        assertGt(ethReceived, minEth);
        assertEq(urlsErc20.balanceOf(BUYER), 0);
    }

    // Test quote functions with 4VS for detailed call stack
    function test_Quotes() public {
        uint256 ethAmount = 1 ether;

        // Test ETH buy quote
        uint256 ethBuyQuote = urls.getEthBuyQuote(ethAmount);
        assertGt(ethBuyQuote, 0);

        // Buy some tokens first before testing sell quote
        vm.deal(BUYER, ethAmount);
        uint256 minTokens = (ethBuyQuote * 95) / 100; // Allow 5% slippage
        vm.prank(BUYER);
        uint256 boughtTokens = urls.buy{value: ethAmount}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            minTokens,
            0
        );

        // Now test token sell quote
        uint256 tokenSellQuote = urls.getTokenSellQuote(boughtTokens);
        assertGt(tokenSellQuote, 0);

        // Graduate market
        _graduateMarket();

        // Test quotes after market graduation
        vm.expectRevert(IUrls.MarketAlreadyGraduated.selector);
        urls.getEthBuyQuote(ethAmount);

        vm.expectRevert(IUrls.MarketAlreadyGraduated.selector);
        urls.getTokenSellQuote(boughtTokens);
    }

    // Helper function to graduate market
    function _graduateMarket() internal {
        // Mock bonding curve to return exact PRIMARY_MARKET_SUPPLY
        vm.mockCall(
            address(bondingCurve),
            abi.encodeWithSelector(
                bytes4(keccak256("getEthBuyQuote(uint256,uint256)"))
            ),
            abi.encode(800_000_000e18)
        );

        vm.mockCall(
            address(bondingCurve),
            abi.encodeWithSelector(
                bytes4(keccak256("getTokenBuyQuote(uint256,uint256)"))
            ),
            abi.encode(1 ether)
        );

        // Mock additional WETH calls needed for graduation
        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.allowance.selector),
            abi.encode(0)
        );

        vm.mockCall(
            WETH,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(1000 ether)
        );

        // Mock NFT position manager mint call
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

        // Buy enough to graduate market
        vm.deal(BUYER, 1 ether);
        uint256 expectedTokens = urls.getEthBuyQuote(0.99 ether); // Account for 1% fee
        uint256 minTokens = (expectedTokens * 95) / 100; // Allow 5% slippage
        vm.prank(BUYER);
        urls.buy{value: 1 ether}(
            BUYER,
            BUYER,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            minTokens,
            0
        );
    }
}
