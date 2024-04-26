// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ERC1155FacetStorage {
    mapping(uint256 => mapping(address => uint256)) _balances;
    mapping(address => mapping(address => bool)) _operatorApprovals;
    mapping(uint256 => uint256) _totalSupply;
    mapping(uint256 => uint256) _totalSupplyNFT;
    mapping(uint256 => address) _nftOwners; // for nftTokenId owner mapping
    mapping(string => uint256) _uriID;
    string _baseURI;
    mapping(uint256 => string) _tokenURIs;
    uint256 _idx;
}
