// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

//TODO: write tests

import "./SetUp.t.sol";

contract ModifyBid is SetUp {
    function testRevert_ModifyBid_Not_Bid_Owner() public {}
    function test_Revert_ModifyBid_Index_Out_Of_Bounds() public {}
    function testRevert_ModifyBid_Offer_Closed() public {}
    function test_ModifyBid() public {}
    function test_Emit_ModifyBid_BidModified() public {}
}
