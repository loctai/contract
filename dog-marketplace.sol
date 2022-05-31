// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";
import "./dog-nft.sol";

contract DOG_Marketplace is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address owner;
    address NFT_Factory;

    uint256 _maxFeeListing = 500;
    uint256 _feeListing = 150;

    uint256 _maxFeeMarket = 500;
    uint256 _feeMarket = 150;

    using SafeERC20 for IERC20;
    IERC20 public BUSD;
    IERC20 public ATH;

    constructor(
        address _Factory,
        address _BUSD,
        address _ATHToken
    ) {
        owner = msg.sender;
        NFT_Factory = _Factory;

        BUSD = IERC20(_BUSD);
        ATH = IERC20(_ATHToken);

        BUSD.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        ATH.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    event BuyNFT(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address newOwner,
        uint256 price,
        bool sold
    );

    event CancelSell(uint256 tokenId);

    modifier onlyOwner(address sender) {
        require(sender == owner, "Is not Owner");
        _;
    }

    /**
     * @dev Set NFT Factory
     */
    function updateFactory(address _Factory) public {
        require(msg.sender == owner, "Only Owner");
        NFT_Factory = _Factory;
    }

    /* Places an item for sale on the marketplace */
    function createSale(
        uint256 tokenId,
        uint256 priceItem
    ) public nonReentrant {
        require(priceItem > 0, "Price must be at least 0");

        require(priceItem > _feeMarket, "Price must be equal to listing price");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[tokenId] = MarketItem(
            itemId,
            NFT_Factory,
            tokenId,
            msg.sender,
            address(0),
            priceItem,
            false
        );

        BUSD.transferFrom(
            msg.sender,
            address(this),
            calculateFee(priceItem, _feeListing)
        );

        DOG_NFT(NFT_Factory).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            NFT_Factory,
            tokenId,
            msg.sender,
            address(0),
            priceItem,
            false
        );
    }

    /* Buy a marketplace item */
    function buyNFT(uint256 tokenId) public nonReentrant {
        uint256 itemId = idToMarketItem[tokenId].itemId;
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        bool is_sold = idToMarketItem[tokenId].sold;

        require(is_sold == false, "Buy NFT : Unavailable");
        require(
            BUSD.balanceOf(msg.sender) >= price,
            "Please submit the asking price in order to complete the purchase"
        );
        BUSD.transferFrom(
            msg.sender,
            idToMarketItem[tokenId].seller,
            price - calculateFee(price, _feeMarket)
        );
        BUSD.transferFrom(
            msg.sender,
            address(this),
            calculateFee(price, _feeMarket)
        );

        DOG_NFT(NFT_Factory).transferFrom(address(this), msg.sender, tokenId);

        idToMarketItem[tokenId].owner = msg.sender;
        idToMarketItem[tokenId].sold = true;

        emit BuyNFT(
            itemId,
            NFT_Factory,
            tokenId,
            seller,
            msg.sender,
            price,
            false
        );

        delete idToMarketItem[tokenId];
        _itemsSold.increment();
    }

    function cancelSell(uint256 tokenId) public nonReentrant {
        bool is_sold = idToMarketItem[tokenId].sold;
        address seller = idToMarketItem[tokenId].seller;

        require(msg.sender == seller, "Buy NFT : Is not Seller");
        require(is_sold == false, "Buy NFT : Unavailable");
        DOG_NFT(NFT_Factory).transferFrom(address(this), msg.sender, tokenId);
        delete idToMarketItem[tokenId];
        emit CancelSell(tokenId);
    }

    function setFeeListing(uint256 fee) public onlyOwner(msg.sender) {
        require(fee <= _maxFeeListing, "Error input, fee < 500");
        _feeListing = fee;
    }

    function setFeeMarket(uint256 fee) public onlyOwner(msg.sender) {
        require(fee <= _maxFeeMarket, "Error input, fee < 500");
        _maxFeeMarket = fee;
    }

    function withdrawFee(address to, uint256 amount)
        public
        onlyOwner(msg.sender)
    {
        BUSD.transferFrom(address(this), to, amount);
    }

    function calculateFee(uint256 amount, uint256 _feePercent)
        public
        pure
        returns (uint256)
    {
        return (amount / 10000) * _feePercent;
    }
    
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 currentCount = _itemIds.current();
        uint256 myNFTCount = 0;
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < currentCount; i++) {
            uint256 latest = i + 1;
            if (idToMarketItem[latest].owner == msg.sender) {
                myNFTCount = myNFTCount + 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](myNFTCount);
        for (uint256 i = 0; i < currentCount; i++) {
            uint256 latest = i + 1;
            if (idToMarketItem[latest].owner == msg.sender) {
                MarketItem memory item = idToMarketItem[latest];
                items[currentIndex] = item;
                currentIndex = currentIndex + 1;
            }
        }
        return items;
    }

    function getAllNFTs() public view returns (MarketItem[] memory) {
        uint256 totalCount = _itemIds.current();
        uint256 currentIndex = 0;
        MarketItem[] memory items = new MarketItem[](totalCount);
        for (uint256 i = 0; i < totalCount; i++) {
            MarketItem memory item = idToMarketItem[i + 1];
            items[currentIndex] = item;
            currentIndex++;
        }
        return items;
    }
}
