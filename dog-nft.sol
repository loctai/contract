// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract DOG_NFT is
    ERC721,
    AccessControlEnumerable,
    ERC721Enumerable,
    Ownable
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(address => bool) public approvalWhitelists;
    mapping(uint256 => bool) public lockedTokens;

    string private _baseTokenURI;
    string private _marketplaceAddress;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        string memory defaultUri,
        address boxAddress,
        address marketplaceAddress
    ) ERC721("DOG_NFT", "DOGN") {
        _baseTokenURI = defaultUri;
        _setupRole(MINTER_ROLE, boxAddress);
        addApprovalWhitelist(marketplaceAddress);
        addApprovalWhitelist(boxAddress);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to) public virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Must have minter role to mint"
        );
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        require(!_exists(tokenId), "Must have unique tokenId");
        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _mint(to, tokenId);
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
        require(approvalWhitelists[proxy] == false, "Invalid proxy address");

        approvalWhitelists[proxy] = true;
    }

    /**
     * @dev Remove operation from approval list.
     */
    function removeApprovalWhitelist(address proxy) public onlyOwner {
        approvalWhitelists[proxy] = false;
    }

    /**
     * @dev Add factory to mint item
     */
    function setMintFactory(address factory) public onlyOwner {
        _setupRole(MINTER_ROLE, factory);
    }

    /**
     * @dev Remove factory
     */
    function removeMintFactory(address factory) public onlyOwner {
        revokeRole(MINTER_ROLE, factory);
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
}
