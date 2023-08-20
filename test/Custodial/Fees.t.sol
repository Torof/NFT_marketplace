// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

//TODO: test fees withdrawing
import "./BaseSetUp.sol";

contract Fees is BaseSetUp {
    function test_Revert_GetEthFees_Not_Owner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _mkpc.getEthFees();
    }

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

    function test_Revert_WithdrawEthFees_Transfer_Reverted() public {
        // vm.startPrank(seller);
        // //Create a sale
        // uint256 salePrice = 2 ether;
        // _mkpc.createSale(address(_nft721), 1, salePrice);

        // vm.prank(buyer);
        // //Buy sale
        // _mkpc.buySale{value: 2 ether}(1);

        // uint256 fees = address(_mkpc).balance;
        // assertEq(fees, 2 ether / 10);

        // vm.expectRevert("Ownable: caller is not the owner");

        // _mkpc.withdrawEthFees();
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

    function test_Revert_GetWethFees_Not_Owner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _mkpc.getWethFees();
    }

    function test_GetWethFees() public {
        vm.prank(seller);
        //Seller creates a new sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        uint256 bidPrice = 1 ether / 2;
        //Bidder approves marketplace to spend WETH on its behalf and creates a new bid on saleOrder 1
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, bidPrice, 2 weeks);
        vm.stopPrank();

        //Check that contract's balance is 0
        vm.prank(owner);
        uint256 balanceContractBefore = _mkpc.getWethFees();
        assertEq(balanceContractBefore, 0);

        vm.startPrank(seller);
        //seller accepts the bid
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();

        uint256 fees = bidPrice / 10;

        vm.startPrank(owner);
        //Check that the fees have been added to contract balance
        uint256 balanceContractAfter = _mkpc.getWethFees();
        assertEq(balanceContractAfter, balanceContractBefore + fees);

        //Withdrawing Weth Fees from contract
        _mkpc.withdrawWethFees();
        uint256 balanceContractAfterWithdraw = _mkpc.getWethFees();
        assertEq(balanceContractAfterWithdraw, 0);
        vm.stopPrank();
    }

    function test_Weth_Fees_Withdraw() public {
        vm.prank(seller);
        //Seller creates a new sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        uint256 bidPrice = 1 ether / 2;
        //Bidder approves marketplace to spend WETH on its behalf and creates a new bid on saleOrder 1
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, bidPrice, 2 weeks);

        vm.startPrank(seller);
        //Check that contract's balance is 0
        uint256 balanceContractBefore = _weth.balanceOf(address(_mkpc));
        assertEq(balanceContractBefore, 0);

        //seller accepts the bid
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();

        uint256 fees = bidPrice / 10;

        //Check that the fees have been added to contract balance
        uint256 balanceContractAfter = _weth.balanceOf(address(_mkpc));
        assertEq(balanceContractAfter, balanceContractBefore + fees);

        uint256 balanceOwnerBeforeWithdraw = _weth.balanceOf(address(owner));
        //Withdrawing Weth Fees from contract
        vm.prank(owner);
        _mkpc.withdrawWethFees();
        uint256 balanceContractAfterWithdraw = _weth.balanceOf(address(_mkpc));
        assertEq(balanceContractAfterWithdraw, 0);
        uint256 balanceOwnerAfterWithdraw = _weth.balanceOf(address(owner));

        assertEq(balanceOwnerBeforeWithdraw + fees, balanceOwnerAfterWithdraw);
    }
}
