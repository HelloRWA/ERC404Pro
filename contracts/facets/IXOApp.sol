// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../storage/facets/AppStorageFacet.sol";

import "../storage/facets/ERC20StorageFacet.sol";
import "../interfaces/IERC20.sol";

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Receiver.sol";
import "../storage/facets/ERC721StorageFacet.sol";

import "../storage/facets/ERC1155StorageFacet.sol";
import "../interfaces/IERC1155Receiver.sol";

import {LibDiamond} from "../libraries/LibDiamond.sol";

contract IXOApp is AppStorageFacet, ERC20StorageFacet, IERC20, ERC721StorageFacet, IERC721, ERC1155StorageFacet {
    function construct(address protocolAddress_, string memory network_, address signer_) external {
        AppStorage storage _s = appStorage();
        _s._name = "$XRC20";
        _s._symbol = "$XRC20";
        _s._protocolAddress = protocolAddress_;
        _s._network = network_;
        _s._signer = signer_;
        _s.platformCommission = 10;

        ERC20FacetStorage storage _ds20 = erc20Storage();
        _ds20._decimals = 18;
        _ds20._totalSupply = 0;

        ERC721FacetStorage storage _ds721 = erc721Storage();
        _ds721._name = "$XRC721";
        _ds721._symbol = "$XRC721";
        _ds721._baseURI = "https://rwa-wallet.com/api/ixo/";

        ERC1155FacetStorage storage _ds1155 = erc1155Storage();
        _ds1155._baseURI = "https://rwa-wallet.com/api/ixo/";
    }

    function setProtocolAddress(address protocolAddress_) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage _s = appStorage();
        _s._protocolAddress = protocolAddress_;
    }

    function setNetwork(string memory network_) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage _s = appStorage();
        _s._network = network_;
    }

    function setSigner(address signer_) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage _s = appStorage();
        _s._signer = signer_;
    }

    function getAppConfig() external view returns (address, string memory, address) {
        AppStorage storage _s = appStorage();
        return (_s._protocolAddress, _s._network, _s._signer);
    }

    function symbol() public view virtual returns (string memory) {
        AppStorage storage _s = appStorage();
        return _s._symbol;
    }

    function name() public view virtual returns (string memory) {
        AppStorage storage _s = appStorage();
        return _s._name;
    }

    function decimals() public view virtual returns (uint8) {
        ERC20FacetStorage storage _ds = erc20Storage();
        return _ds._decimals;
    }

    function totalSupply() external view returns (uint256) {
        ERC20FacetStorage storage _ds = erc20Storage();
        return _ds._totalSupply;
    }

    function balanceOf(address account_) external view returns (uint256) {
        ERC20FacetStorage storage _ds = erc20Storage();
        return _ds._balances[account_];
    }

    function allowance(address owner_, address spender_) public view returns (uint256) {
        ERC20FacetStorage storage _ds = erc20Storage();
        return _ds._allowances[owner_][spender_];
    }

    function _mintXRC20(address to_, uint256 amount_) private returns (bool) {
        require(to_ != address(0), "ERC20: can't mint to 0 address");
        ERC20FacetStorage storage _ds = erc20Storage();
        _ds._totalSupply += amount_;
        _ds._balances[to_] += amount_;

        emit Transfer(address(0), to_, amount_);
        return true;
    }

    function _burn(address from_, uint256 amount_) private returns (bool) {
        require(from_ != address(0), "ERC20: can't burn from 0 address");

        ERC20FacetStorage storage _ds = erc20Storage();

        require(_ds._balances[from_] >= amount_, "ERC20: Insufficient Funds");

        _ds._balances[from_] -= amount_;
        _ds._totalSupply -= amount_;

        emit Transfer(from_, address(0), amount_);
        return true;
    }

    event MintViaSign(string nonce, address to, uint256 tokenId, uint256 amount);

    function mintXRC20(address to, uint256 amount, string memory nonce, bytes memory signature) public {
        uint256 tokenId = 0;
        require(verify(to, tokenId, amount, address(0), 0, nonce, signature), "signature is invalidate");
        AppStorage storage _ds = appStorage();

        _ds._nonceMap[nonce] = true;
        require(_mintXRC20(to, amount), "Mint failed");
        emit MintViaSign(nonce, to, tokenId, amount);
    }

    function mintXRC721(address to, uint256 tokenId, address payment, uint256 payAmount, string memory nonce, bytes memory signature) public {
        uint256 amount = 1;
        AppStorage storage _ds = appStorage();
        require(verify(to, tokenId, amount, payment, payAmount, nonce, signature), "signature is invalidate");
        _ds._nonceMap[nonce] = true;

        bool payRz = receivePayment(msg.sender, payAmount, payment);
        require(payRz, "insufficient funds");

        require(_mintXRC721(to, tokenId), "Mint failed");
        splitCommission(msg.sender, tokenId, payment, payAmount);
        emit MintViaSign(nonce, to, tokenId, amount);
    }

    function mintXRC1155FT(
        address to,
        uint256 tokenId_,
        uint256 amount_,
        address payment,
        uint256 payAmount,
        string memory nonce,
        bytes memory signature
    ) public {
        require(to != address(0), "ERC1155: address zero is not a valid owner");
        ERC721FacetStorage storage _ds721 = erc721Storage();
        require(_ds721._owners[tokenId_] != address(0), "Project not launched!");

        require(verify(to, tokenId_, amount_, payment, payAmount, nonce, signature), "signature is invalidate");
        AppStorage storage _ds = appStorage();

        bool payRz = receivePayment(msg.sender, payAmount, payment);
        require(payRz, "insufficient funds");

        _ds._nonceMap[nonce] = true;

        ERC1155FacetStorage storage _ds1155 = erc1155Storage();

        uint256 totalSupplyValue = _ds1155._totalSupplyNFT[tokenId_] * 10000 + _ds1155._totalSupply[tokenId_] + amount_;
        require(totalSupplyValue <= 10000 * 10000, "XRC1155: Exceeded max total supply");

        _ds1155._totalSupply[tokenId_] += amount_;
        _ds1155._balances[tokenId_][to] += amount_;

        emit TransferSingle(msg.sender, address(0), to, tokenId_, amount_);
        emit MintViaSign(nonce, to, tokenId_, amount_);

        require(_checkOnERC1155Received(address(0), to, tokenId_, amount_, ""), "ERC1155: transfer to non ERC1155Receiver implementer");
        splitCommission(msg.sender, tokenId_, payment, payAmount);
    }

    function mintXRC1155NFT(address to, uint256 nftTokenId_, address payment, uint256 payAmount, string memory nonce, bytes memory signature) public {
        require(to != address(0), "ERC1155: address zero is not a valid owner");

        // 123 * 10**10 + 456
        uint256 tokenId_ = nftTokenId_ / (10 ** 10); // 123
        uint256 gridId_ = nftTokenId_ % (10 ** 10); // 456
        require(gridId_ <= 10000, "XRC1155: gridId must gte 10000");

        ERC721FacetStorage storage _ds721 = erc721Storage();
        require(_ds721._owners[tokenId_] != address(0), "Project not launched!");

        uint256 amount_ = 1;
        require(verify(to, nftTokenId_, amount_, payment, payAmount, nonce, signature), "signature is invalidate");
        AppStorage storage _ds = appStorage();

        bool payRz = receivePayment(msg.sender, payAmount, payment);
        require(payRz, "insufficient funds");

        _ds._nonceMap[nonce] = true;

        ERC1155FacetStorage storage _ds1155 = erc1155Storage();

        require(_ds1155._nftOwners[nftTokenId_] == address(0), "XRC1155: this nft tokenId already minted!");

        uint256 totalSupplyValue = _ds1155._totalSupplyNFT[tokenId_] * 10000 + _ds1155._totalSupply[tokenId_] + 10000;
        require(totalSupplyValue <= 10000 * 10000, "XRC1155: Exceeded max total supply");

        _ds1155._totalSupplyNFT[tokenId_] += 1;
        _ds1155._nftOwners[nftTokenId_] = to;

        // emit TransferSingle(msg.sender, address(0), to, nftTokenId_, amount_);
        emit MintViaSign(nonce, to, nftTokenId_, amount_);

        require(_checkOnERC1155Received(address(0), to, nftTokenId_, amount_, ""), "ERC1155: transfer to non ERC1155Receiver implementer");
        splitCommission(msg.sender, tokenId_, payment, payAmount);
    }

    function verify(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        address payment,
        uint256 payAmount,
        string memory _nonce,
        bytes memory signature
    ) public view returns (bool) {
        AppStorage storage _ds = appStorage();

        require(_ds._nonceMap[_nonce] == false, "nonce already used");

        bytes32 messageHash = getMessageHash(_to, _tokenId, _amount, payment, payAmount, _nonce, _ds._protocolAddress);

        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        address theSigner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)), v, r, s);
        return theSigner == _ds._signer;
    }

    function getMessageHash(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        address payment,
        uint256 payAmount,
        string memory _nonce,
        address _currentContractAddress
    ) public view returns (bytes32) {
        AppStorage storage _s = appStorage();
        return keccak256(abi.encodePacked(_to, _tokenId, _amount, payment, payAmount, _nonce, _s._network, _currentContractAddress));
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function tokenURI(uint256 tokenID_) public view returns (string memory) {
        ERC721FacetStorage storage _ds = erc721Storage();
        require(_ds._owners[tokenID_] != address(0), "ERC721: invalid token ID");
        return string(abi.encodePacked(_ds._baseURI, tokenID_));
    }

    function getApproved(uint256 tokenId) external view returns (address operator) {
        ERC721FacetStorage storage _ds = erc721Storage();
        return _ds._tokenApprovals[tokenId];
    }

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    function _checkOnERC1155Received(address from_, address to_, uint256 tokenID_, uint256 amount_, bytes memory data_) private returns (bool) {
        if (to_.code.length == 0) {
            return true;
        }

        try IERC1155Receiver(to_).onERC1155Received(msg.sender, from_, tokenID_, amount_, data_) returns (bytes4 retval) {
            return retval == IERC1155Receiver.onERC1155Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    function _mintXRC721(address to_, uint256 _tokenID) private returns (bool) {
        require(to_ != address(0), "ERC721: Cannot transfer to 0 address");

        ERC721FacetStorage storage _ds = erc721Storage();
        require(_ds._owners[_tokenID] == address(0), "ERC721: NFT already minted");

        _ds._balances[to_] += 1;
        _ds._owners[_tokenID] = to_;

        emit Transfer(address(0), to_, _tokenID);
        return true;
    }

    function transfer(address to_, uint256 amountOrTokenId_) external returns (bool) {
        if (amountOrTokenId_ > 10000) {
            return _transferXRC20(msg.sender, to_, amountOrTokenId_);
        }
        return _transferXRC721(msg.sender, to_, amountOrTokenId_);
    }

    function transferFrom(address from_, address to_, uint256 amountOrTokenId_) external returns (bool) {
        if (amountOrTokenId_ > 10000) {
            _requireAllowanceXRC20(from_, to_, amountOrTokenId_);
            return _transferXRC20(from_, to_, amountOrTokenId_);
        }

        _requireXRC721Auth(from_, amountOrTokenId_);
        return _transferXRC721(from_, to_, amountOrTokenId_);
    }

    function safeTransferFrom(address from_, address to_, uint256 tokenID_, bytes memory data_) public {
        _requireXRC721Auth(msg.sender, tokenID_);
        _safeTransferXRC721(from_, to_, tokenID_, data_);
    }

    function _safeTransferXRC721(address from_, address to_, uint256 tokenID_, bytes memory data_) internal {
        _transferXRC721(from_, to_, tokenID_);
        _requireXRC721Reciever(from_, to_, tokenID_, data_);
    }

    function _requireXRC721Reciever(address from_, address to_, uint256 tokenID_, bytes memory data_) private {
        require(_checkOnERC721Received(from_, to_, tokenID_, data_), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _checkOnERC721Received(address from_, address to_, uint256 tokenID_, bytes memory data_) private returns (bool) {
        if (to_.code.length > 0) {
            try IERC721Receiver(to_).onERC721Received(msg.sender, from_, tokenID_, data_) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function safeTransferFrom(address from_, address to_, uint256 tokenID_) external {
        safeTransferFrom(from_, to_, tokenID_, "");
    }

    function approve(address spender_, uint256 amountOrTokenId_) external returns (bool) {
        if (amountOrTokenId_ > 10000) {
            return _approveXRC20(msg.sender, spender_, amountOrTokenId_);
        }

        return _approveXRC721(msg.sender, spender_, amountOrTokenId_);
    }

    function _requireXRC721Auth(address from_, uint256 tokenID_) private view {
        require(_hasXRC721Auth(from_, tokenID_), "ERC721: Not token owner or approved");
    }

    function _hasXRC721Auth(address from_, uint256 tokenID_) internal view returns (bool) {
        address _owner = _ownerXRC721(tokenID_);
        return _owner == from_ || isApprovedForAll(_owner, from_);
    }

    function isApprovedForAll(address owner_, address operator_) public view returns (bool) {
        AppStorage storage _ds = appStorage();
        return _ds._operatorApprovals[owner_][operator_];
    }

    function setApprovalForAll(address operator_, bool approved_) external {
        require(msg.sender != operator_, "IXO: Cannot set approval status for self");

        AppStorage storage _ds = appStorage();
        _ds._operatorApprovals[msg.sender][operator_] = approved_;

        emit ApprovalForAll(msg.sender, operator_, approved_);
    }

    function _approveXRC721(address owner_, address operator_, uint256 tokenID_) private returns (bool) {
        require(ownerOfXRC721(tokenID_) != operator_, "ERC721: Approval to current owner");
        _requireXRC721Auth(owner_, tokenID_);

        ERC721FacetStorage storage _ds = erc721Storage();
        _ds._tokenApprovals[tokenID_] = operator_;

        emit Approval(ownerOfXRC721(tokenID_), operator_, tokenID_);
        return true;
    }

    function ownerOf(uint256 tokenID_) public view virtual returns (address) {
        return ownerOfXRC721(tokenID_);
        // TODO: XRC1155
    }

    function ownerOfXRC721(uint256 tokenID_) public view virtual returns (address) {
        _requireXRC721Minted(tokenID_);
        return _ownerXRC721(tokenID_);
    }

    function _requireFundsXRC20(address from_, uint256 amount_) private view {
        ERC20FacetStorage storage _ds = erc20Storage();

        require(_ds._balances[from_] >= amount_, "ERC20: Insufficient Funds");
    }

    function _requireAllowanceXRC20(address owner_, address spender_, uint256 amount_) private view {
        ERC20FacetStorage storage _ds = erc20Storage();
        require(_ds._allowances[owner_][spender_] >= amount_, "ERC20: Insufficient Allowance");
    }

    function _approveXRC20(address approver_, address spender_, uint256 amount_) private returns (bool) {
        _requireFundsXRC20(approver_, amount_);

        ERC20FacetStorage storage _ds = erc20Storage();
        _ds._allowances[approver_][spender_] = amount_;

        emit Approval(approver_, spender_, amount_);
        return true;
    }

    function _transferXRC20(address from_, address to_, uint256 amount_) private returns (bool) {
        _requireFundsXRC20(from_, amount_);

        ERC20FacetStorage storage _ds = erc20Storage();
        _ds._balances[from_] -= amount_;
        _ds._balances[to_] += amount_;

        emit Transfer(from_, to_, amount_);
        return true;
    }

    function _transferXRC721(address from_, address to_, uint256 tokenID_) private returns (bool) {
        require(to_ != address(0), "ERC721: Cannot transfer to 0 address");
        // _requireXRC721Minted(tokenID_);
        _requireXRC721Owner(from_, tokenID_);
        /* _requireAuth(from_, tokenID_); */

        ERC721FacetStorage storage _ds = erc721Storage();

        delete _ds._tokenApprovals[tokenID_];
        _ds._owners[tokenID_] = to_;
        _ds._balances[msg.sender] -= 1;
        _ds._balances[to_] += 1;

        emit Transfer(msg.sender, to_, tokenID_);
        return true;
    }

    function _requireXRC721Minted(uint256 tokenId) internal view virtual {
        require(_existsXRC721(tokenId), "ERC721: invalid token ID");
    }

    function _existsXRC721(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerXRC721(tokenId) != address(0);
    }

    function _ownerXRC721(uint256 tokenID_) internal view returns (address) {
        ERC721FacetStorage storage _ds = erc721Storage();
        return _ds._owners[tokenID_];
    }

    function _requireXRC721Owner(address from_, uint256 tokenID_) private view {
        require(_ownerXRC721(tokenID_) == from_, "ERC721: Not token owner");
    }
}
r