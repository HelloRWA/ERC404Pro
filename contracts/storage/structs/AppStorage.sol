// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct AppStorage {
    address _protocolAddress;
    string _network;
    address _signer;
    string _name;
    string _symbol;
    mapping(address => mapping(address => bool)) _operatorApprovals;
    mapping(string => bool) _nonceMap;
    mapping(address => bool) _paymentList;
    mapping(uint256 => uint256) _inviteCommissionMap; // tokenId => commission
    mapping(uint256 => mapping(address => address)) _inviteByMap; // tokenId => (userAddress => inviterAddress)
    mapping(address => mapping(address => uint256)) _inviterBalanceMap; // userAddress=> (payment => amount)
    uint256 platformCommission; // 100 == 1%, 1000 == 10%
    mapping(address => uint256) platformCommissionBalance;
    mapping(uint256 => mapping(address => uint256)) tokenVaultMap;
}
