// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./BaseSetUp.sol";

contract Security_Checks is BaseSetUp {
    uint256[] helperId = [1, 2];
    uint256[] helperAmount = [1, 1];

    function test_SupportInterface(bytes4 wrongInterfaceId) public {
        bool supportsIERC721Receiver = _mkpc.supportsInterface(type(IERC721Receiver).interfaceId);
        bool supportsIERC1155Receiver = _mkpc.supportsInterface(type(IERC1155Receiver).interfaceId);
        bool supportsIERC165 = _mkpc.supportsInterface(type(IERC165).interfaceId);

        bool otherbytes4 = _mkpc.supportsInterface(wrongInterfaceId);

        assertTrue(supportsIERC721Receiver);
        assertTrue(supportsIERC1155Receiver);
        assertTrue(supportsIERC165);
        assertFalse(otherbytes4);
    }

    function test_onErc721Received() public {
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

    ///TODO: call return = true ? ===> use mockcall()
    function test_Revert_Receive_function() public {
        vm.startPrank(buyer);
        vm.expectRevert();
        (bool sent,) = address(_mkpc).call{value: 1 ether}("");
        assertTrue(sent);
    }

    //TODO: call return = true ? ===> use mockcall()
    function test_Revert_Fallback_function() public {
        vm.startPrank(buyer);
        vm.expectRevert("not allowed fallback");
        (bool sent,) = address(_mkpc).call("");
        assertTrue(sent);
    }

    //Direct transfer from safeTransferFrom() disabled
    function test_Revert_On_Direct_Transfer() public {
        //Should revert if NFT is sent directly with SafeTransferFrom
        vm.startPrank(seller, seller);
        vm.expectRevert("direct transfer not allowed");
        _nft721.safeTransferFrom(seller, address(_mkpc), 1);
    }

    function test_revert_unlockNFft_If_Caller_Is_Not_Contract_Owner(address randomAddress) public {
        vm.startPrank(seller);
        ///Unsafe transfer of NFT to markeplace
        _nft721.transferFrom(seller, address(_mkpc), 1);
        ///Check markeplace is owner of NFT
        assertEq(_nft721.ownerOf(1), address(_mkpc));
        ///TODO: check if locked

        ///Revert if caller is not contract owner
        vm.expectRevert("Ownable: caller is not the owner");

        _mkpc.unlockNFT(address(_nft721), 1, randomAddress);
        vm.stopPrank();
    }

    function test_unlockNFT() public {
        vm.startPrank(seller);
        ///Unsafe transfer of NFT to markeplace
        _nft721.transferFrom(seller, address(_mkpc), 1);
        ///Check markeplace is owner of NFT
        assertEq(_nft721.ownerOf(1), address(_mkpc));
        vm.startPrank(owner);
        _mkpc.unlockNFT(address(_nft721), 1, seller);
    }
}
