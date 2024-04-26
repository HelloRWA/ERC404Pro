// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../storage/facets/ERC721StorageFacet.sol";

contract XRC721 is ERC721StorageFacet {
    function nameERC721() public view virtual returns (string memory) {
        ERC721FacetStorage storage _ds = erc721Storage();
        return _ds._name;
    }

    function symbolERC721() public view virtual returns (string memory) {
        ERC721FacetStorage storage _ds = erc721Storage();
        return _ds._symbol;
    }

    function balanceOfERC721(address account_) external view returns (uint256) {
        ERC721FacetStorage storage _ds = erc721Storage();
        return _ds._balances[account_];
    }
}
