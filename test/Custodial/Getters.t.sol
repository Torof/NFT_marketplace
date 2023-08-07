// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./SetUp.t.sol";

contract Getters is SetUp {
    function test_GetEthFees() public {}

    function test_Revert_GetEthFees_If_Not_Owner() public {}

    function test_GetWEthFees() public {}

    function test_Revert_GetWEthFees_If_Not_Owner() public {}

    function test_GetSaleOrder() public {}
}
