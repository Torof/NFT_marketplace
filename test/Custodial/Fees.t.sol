// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

//TODO: test fees withdrawing
import "./SetUp.t.sol";

contract Fees is SetUp {
    function test_Eth_Fees_Distributed() public {
        vm.startPrank(seller);
        //Create a sale
        uint256 salePrice = 2 ether;
        _mkpc.createSale(address(_nft721), 1, salePrice);

        vm.prank(buyer);
        //Buy sale
        _mkpc.buySale{value: 2 ether}(1);

        uint256 fees = (address(_mkpc).balance);
        assertEq(fees, salePrice / 10);
    }

    function test_Eth_Fees_Withdraw() public {}

    function test_Weth_Fees_Distributed() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        vm.startPrank(seller);

        _mkpc.acceptBid(1, 0);
        vm.stopPrank();

        uint256 fees = _weth.balanceOf(address(_mkpc));
        assertEq(fees, (1 ether * (5 / 10)) / 10);
    }

    function test_Weth_Fees_Withdraw() public {}
}
