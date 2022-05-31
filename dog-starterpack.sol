// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./dog-nft.sol";
import "./dog-userpool.sol";

contract DOG_StarterPack is
    ERC721,
    AccessControlEnumerable,
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // ONLY ALLOW BUSD
    using SafeERC20 for IERC20;
    IERC20 public BUSD;
    IERC20 public DOG;
    DOG_NFT public FactoryNFT;
    UserPool public Pool;

    // EVENT

    event BuyStarterPack(uint256 indexed tokenId, address addressWallet);

    event OpenPackSuccess(
        uint256 packId,
        address addressWallet,
        address contractCreate
    );

    // STATE
    mapping(address => bool) public approvalWhitelists;
    mapping(uint256 => bool) public lockedTokens;
    mapping(uint256 => bool) public isOpen;


    string private _baseTokenURI;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public totalStarterPack;
    uint256 public totalSoldStarterPack;
    uint256 public priceStarterPack;

    uint256 public totalItemInPack;
    uint256 public totalDOGInPack;

    uint256 public percentStarterPack = 6000; // 60%

    bool public saleEnded;

    constructor(
        string memory baseTokenURI,
        address _BUSD,
        address _DOG,
        address _Pool,
        address _Factory
    ) ERC721("DOG Pack", "DOGP") {
        BUSD = IERC20(_BUSD);
        DOG = IERC20(_DOG);
        Pool = UserPool(_Pool);
        FactoryNFT = DOG_NFT(_Factory);
        BUSD.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        DOG.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        _baseTokenURI = baseTokenURI;
        _setupRole(MINTER_ROLE, _msgSender());
    }

    modifier checkSaleStarterPackRequirements(address _msgSender) {
        uint256 allowToPayAmount = BUSD.allowance(_msgSender, address(this));
        require(
            allowToPayAmount >= priceStarterPack,
            "Box Payment: Invalid token allowance"
        );
        require(
            BUSD.balanceOf(_msgSender) >= priceStarterPack,
            "Box Payment: Invalid balanceOf"
        );

        require(unsoldPack() > 0, "Insufficient buy amount");
        _;
    }

    modifier checkOpenPack(uint256 tokenId) {
        require(
            ownerOf(tokenId) == _msgSender(),
            "Box Open : must have owner role to open"
        );
        require(isOpen[tokenId] == false, "Box Open : box is opened");
        require(!lockedTokens[tokenId], "Box Open : box is locked");
        require(
            FactoryNFT.hasRole(MINTER_ROLE, address(this)) == true,
            "Box Open : is error of Pack Contract"
        );
        _;
    }

    function buyStarterPack(address to)
        public
        virtual
        checkSaleStarterPackRequirements(_msgSender())
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        require(!_exists(newItemId), "Pack Payment: must have unique tokenId");

        BUSD.transferFrom(_msgSender(), address(Pool), priceStarterPack);

        _mint(to, newItemId);
        isOpen[newItemId] = false;
        emit BuyStarterPack(newItemId, _msgSender());
    }

    function openStarterPack(uint256 boxId) public checkOpenPack(boxId) {
        for (uint256 index = 0; index < totalItemInPack; index++) {
            FactoryNFT.mint(_msgSender());
        }

        uint256 totalPool = calculateFee(priceStarterPack, percentStarterPack);
        Pool.augmentPoolBUSD(_msgSender(), totalPool);
        Pool.augmentPoolDOG(_msgSender(), totalDOGInPack);
        isOpen[boxId] = true;

        emit OpenPackSuccess(
            boxId,
            _msgSender(),
            address(FactoryNFT)
        );
    }

    function setTotalItemInPack(uint256 _total) public onlyOwner {
        totalItemInPack = _total;
    }

    function setTotalDOGInPack(uint256 _total) public onlyOwner {
        totalDOGInPack = _total;
    }

    /**
     * @dev caculateDiscount;
     */
    function calculateFee(uint256 amount, uint256 _feePercent)
        public
        pure
        returns (uint256)
    {
        return (amount / 10000) * _feePercent;
    }

    /**
     * @dev Set BUSD
     */
    function setBUSD(address _addressBUSD) public onlyOwner {
        BUSD = IERC20(_addressBUSD);
    }

    function setFactory(address _addressFactory) public onlyOwner {
        FactoryNFT = DOG_NFT(_addressFactory);
    }

    function setPrice(uint256 price) public onlyOwner {
        priceStarterPack = price;
    }

    function setTotalPack(uint256 amount) public onlyOwner {
        totalStarterPack = amount;
    }

    function unsoldPack() public view returns (uint256) {
        return uint256(totalStarterPack - totalSoldStarterPack);
    }

    /**
     * @dev Lock token to use in game or for rental
     */
    function lock(uint256 tokenId) public {
        require(
            approvalWhitelists[_msgSender()],
            "Must be valid approval whitelist"
        );
        require(_exists(tokenId), "Must be valid tokenId");
        require(!lockedTokens[tokenId], "Token has already locked");
        lockedTokens[tokenId] = true;
    }

    /**
     * @dev Unlock token to use blockchain or sale on marketplace
     */
    function unlock(uint256 tokenId) public {
        require(
            approvalWhitelists[_msgSender()],
            "Must be valid approval whitelist"
        );
        require(_exists(tokenId), "Must be valid tokenId");
        require(lockedTokens[tokenId], "Token has already unlocked");
        lockedTokens[tokenId] = false;
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        if (approvalWhitelists[operator] == true) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev Allow operation to reduce gas fee.
     */
    function addApprovalWhitelist(address proxy) public onlyOwner {
        require(
            approvalWhitelists[proxy] == false,
            "GameNFT: invalid proxy address"
        );

        approvalWhitelists[proxy] = true;
    }

    /**
     * @dev Remove operation from approval list.
     */
    function removeApprovalWhitelist(address proxy) public onlyOwner {
        approvalWhitelists[proxy] = false;
    }

    /**
     * @dev Get lock status
     */
    function isLocked(uint256 tokenId) public view returns (bool) {
        return lockedTokens[tokenId];
    }

    /**
     * @dev Set token URI
     */
    function updateBaseURI(string calldata baseTokenURI) public onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev See {IERC165-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        require(!lockedTokens[tokenId], "Can not transfer locked token");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Update baseURI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
