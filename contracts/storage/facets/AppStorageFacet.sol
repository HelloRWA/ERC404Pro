// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import "../structs/AppStorage.sol";

interface _IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract AppStorageFacet {
    AppStorage internal s;

    function appStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }

    function _checkPayment(address payment) internal view returns (bool) {
        AppStorage storage _ds = appStorage();
        return _ds._paymentList[payment];
    }

    event AddInviteCommission(uint256 tokenId, address inviter, address invitee, address payment, uint256 inviterBalanceDelta);
    event AddPlatformIncome(uint256 tokenId, address userAddress, address payment, uint256 platformCommissionDelta);
    event AddTokenVault(uint256 tokenId, address userAddress, address payment, uint256 tokenVaultDelta);

    function splitCommission(address userAddress, uint256 tokenId, address payment, uint256 payAmount) internal {
        AppStorage storage ds = appStorage();

        uint256 inviteCommission = ds._inviteCommissionMap[tokenId];

        uint256 inviterBalanceDelta = 0;

        address inviter = ds._inviteByMap[tokenId][userAddress];
        if (inviter != address(0) && inviteCommission > 0) {
            inviterBalanceDelta = (inviteCommission * payAmount) / 10000;
            ds._inviterBalanceMap[inviter][payment] += inviterBalanceDelta;
            emit AddInviteCommission(tokenId, inviter, userAddress, payment, inviterBalanceDelta);
        }

        uint256 platformCommissionDelta = (ds.platformCommission * payAmount) / 10000;

        ds.platformCommissionBalance[payment] += platformCommissionDelta;
        emit AddPlatformIncome(tokenId, userAddress, payment, platformCommissionDelta);

        uint256 tokenVaultDelta = payAmount - (inviterBalanceDelta + platformCommissionDelta);
        ds.tokenVaultMap[tokenId][payment] += tokenVaultDelta;
        emit AddTokenVault(tokenId, userAddress, payment, tokenVaultDelta);
    }

    function receivePayment(address sender, uint256 payAmount, address payment) internal returns (bool) {
        if (!_checkPayment(payment)) return false;
        return (_IERC20(payment)).transferFrom(sender, address(this), payAmount);
    }
}
