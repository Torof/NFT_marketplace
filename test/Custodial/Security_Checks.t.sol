// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./SetUp.t.sol";

contract Security_Checks is SetUp {
    function test_SetUp() public {}

    ///BUG: should revert
    function testFail_Receive_function() public {
        vm.prank(buyer);
        // vm.expectRevert();
        (bool sent,) = address(_mkpc).call{value: 1 ether}("");
        assertEq(sent, true);
    }

    function testFail_Fallback_function() public {
        vm.prank(buyer);
        vm.expectRevert("not allowed fallback");
        (bool sent,) = address(_mkpc).call("");
        assertFalse(sent);
    }

    //Direct transfer from safeTransferFrom() disabled
    function test_Revert_On_Direct_Transfer() public {
        //Should revert if NFT is sent directly with SafeTransferFrom
        vm.prank(seller, seller);
        vm.expectRevert("direct transfer not allowed");
        _nft721.safeTransferFrom(seller, address(_mkpc), 1);
    }

    function test_Revert_UnlockNFT_If_Caller_Is_Not_Contract_Owner() public {
        vm.startPrank(seller);
        ///Unsafe transfer of NFT to markeplace
        _nft721.transferFrom(seller, address(_mkpc), 1);
        ///Check markeplace is owner of NFT
        assertEq(_nft721.ownerOf(1), address(_mkpc));
        ///TODO: check if locked

        ///Revert if caller is not contract owner
        vm.expectRevert("Ownable: caller is not the owner");

        _mkpc.unlockNFT(address(_nft721), 1, seller);
        vm.stopPrank();
    }

    function test_UnlockNFT() public {
        vm.prank(seller);
        ///Unsafe transfer of NFT to markeplace
        _nft721.transferFrom(seller, address(_mkpc), 1);
        ///Check markeplace is owner of NFT
        assertEq(_nft721.ownerOf(1), address(_mkpc));
        vm.prank(owner);
        _mkpc.unlockNFT(address(_nft721), 1, seller);
    }
}