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

    //TODO write asserts
    function test_WithdrawEthFees() public {
        vm.startPrank(seller);
        //Create a sale
        uint256 salePrice = 2 ether;
        _mkpc.createSale(address(_nft721), 1, salePrice);

        vm.prank(buyer);
        //Buy sale
        _mkpc.buySale{value: 2 ether}(1);

        vm.prank(owner);
        _mkpc.withdrawEthFees();
    }

    function test_Revert_WithdrawEthFees_Not_Contract_Owner() public {
        vm.startPrank(seller);
        //Create a sale
        uint256 salePrice = 2 ether;
        _mkpc.createSale(address(_nft721), 1, salePrice);

        vm.prank(buyer);
        //Buy sale
        _mkpc.buySale{value: 2 ether}(1);

        uint256 fees = address(_mkpc).balance;
        assertEq(fees, 2 ether / 10);

        vm.expectRevert("Ownable: caller is not the owner");

        _mkpc.withdrawEthFees();
    }

    function test_Weth_Fees_Distributed() public {
        vm.prank(seller);
        //Seller creates a new sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        uint256 bidPrice = 1 ether * (5 / 10);
        //Bidder approves marketplace to spend WETH on its behalf and creates a new bid on saleOrder 1
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, bidPrice, 2 weeks);

        vm.startPrank(seller);
        //Check that contract's balance is 0
        uint256 balanceBefore = _weth.balanceOf(address(_mkpc));
        assertEq(balanceBefore, 0);

        //seller accepts the bid
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();

        //Check that the fees have been added to contract balance
        uint256 balanceAfter = _weth.balanceOf(address(_mkpc));
        assertEq(balanceAfter, balanceBefore + (bidPrice / 10));
    }

    //BUG: ERC20 insufficient allowance
    function test_Weth_Fees_Withdraw() public {
        vm.prank(seller);
        //Seller creates a new sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        uint256 bidPrice = 1 ether * (5 / 10);
        //Bidder approves marketplace to spend WETH on its behalf and creates a new bid on saleOrder 1
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, bidPrice, 2 weeks);

        vm.startPrank(seller);
        //Check that contract's balance is 0
        uint256 balanceBefore = _weth.balanceOf(address(_mkpc));
        assertEq(balanceBefore, 0);

        //seller accepts the bid
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();

        //Check that the fees have been added to contract balance
        uint256 balanceAfter = _weth.balanceOf(address(_mkpc));
        assertEq(balanceAfter, balanceBefore + (bidPrice / 10));
    }
}
