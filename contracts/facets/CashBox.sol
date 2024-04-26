// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import "../storage/facets/AppStorageFacet.sol";
import "../storage/facets/ERC721StorageFacet.sol";

contract CashBox is AppStorageFacet, ERC721StorageFacet {
    function updatePayment(address payment, bool isEnabled) public returns (bool) {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage ds = appStorage();
        ds._paymentList[payment] = isEnabled;
        return true;
    }

    function checkPayment(address payment) public view returns (bool) {
        return _checkPayment(payment);
    }

    function getInviteBalance(address inviter, address payment) public view returns (uint256) {
        AppStorage storage ds = appStorage();
        return ds._inviterBalanceMap[inviter][payment];
    }

    event WithdrawInviteBalance(address sendTo, address payment, uint256 amount);

    function withdrawInviteBalance(address payment) public returns (uint256) {
        AppStorage storage ds = appStorage();
        uint256 amount = ds._inviterBalanceMap[msg.sender][payment];
        ds._inviterBalanceMap[msg.sender][payment] = 0;

        require(amount > 0, "CashBox: balance is zero");
        require((_IERC20(payment)).transferFrom(address(this), msg.sender, amount), "transfer failed");
        emit WithdrawInviteBalance(msg.sender, payment, amount);
        return amount;
    }

    function getPlatformCommissionBalance(address payment) public view returns (uint256) {
        AppStorage storage ds = appStorage();
        return ds.platformCommissionBalance[payment];
    }

    function withdraw(address payment, uint256 amount) public returns (uint256) {
        LibDiamond.enforceIsContractOwner();
        require((_IERC20(payment)).transferFrom(address(this), msg.sender, amount), "transfer failed");
        return amount;
    }

    function getTokenVaultBalance(uint256 tokenId, address payment) public view returns (uint256) {
        AppStorage storage ds = appStorage();
        return ds.tokenVaultMap[tokenId][payment];
    }

    event WithdrawTokenVaultBalance(uint256 tokenId, address sendTo, address payment, uint256 amount);

    function withdrawTokenVaultBalance(uint256 tokenId, address payment) public returns (uint256) {
        ERC721FacetStorage storage _ds = erc721Storage();
        require(_ds._owners[tokenId] == msg.sender, "CashBox: You are not the token owner");

        AppStorage storage ds = appStorage();
        uint256 amount = ds.tokenVaultMap[tokenId][payment];
        ds.tokenVaultMap[tokenId][payment] = 0;
        require(amount > 0, "CashBox: balance is zero");
        require((_IERC20(payment)).transferFrom(address(this), msg.sender, amount), "transfer failed");
        emit WithdrawTokenVaultBalance(tokenId, msg.sender, payment, amount);
        return amount;
    }
}
