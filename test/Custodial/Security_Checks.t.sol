// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./SetUp.t.sol";

contract Security_Checks is SetUp {
    uint256[] helperId = [1, 2];
    uint256[] helperAmount = [1, 1];

    function test_SupportInterface() public {}

    function test_OnERC721Received() public {
        (bytes4 ERC721selector) = _mkpc.onERC721Received((address(_mkpc)), seller, 1, "");
        assertEq(ERC721selector, IERC721Receiver.onERC721Received.selector);
    }

    function test_OnERC1155Received() public {
        (bytes4 ERC1155selector) = _mkpc.onERC1155Received((address(_mkpc)), seller, 1, 1, "");
        assertEq(ERC1155selector, IERC1155Receiver.onERC1155Received.selector);
    }

    function test_OnERC1155BatchReceived() public {
        (bytes4 ERC1155Batchselector) =
            _mkpc.onERC1155BatchReceived((address(_mkpc)), seller, helperId, helperAmount, "");
        assertEq(ERC1155Batchselector, IERC1155Receiver.onERC1155BatchReceived.selector);
    }

    ///TODO: call return = true ?
    function test_Revert_Receive_function() public {
        vm.prank(buyer);
        vm.expectRevert();
        (bool sent,) = address(_mkpc).call{value: 1 ether}("");
        assertTrue(sent);
    }

    //TODO: call return = true ?
    function test_Revert_Fallback_function() public {
        vm.prank(buyer);
        vm.expectRevert("not allowed fallback");
        (bool sent,) = address(_mkpc).call("");
        assertTrue(sent);
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
