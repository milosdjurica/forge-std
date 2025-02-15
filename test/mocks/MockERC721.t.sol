// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {MockERC721, IERC721TokenReceiver} from "../../src/mocks/MockERC721.sol";
import {StdCheats} from "../../src/StdCheats.sol";
import {Test} from "../../src/Test.sol";

contract ERC721Recipient is IERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(address _operator, address _from, uint256 _id, bytes calldata _data)
        public
        virtual
        override
        returns (bytes4)
    {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return IERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is IERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is IERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract Token_ERC721 is MockERC721 {
    constructor(string memory _name, string memory _symbol) {
        initialize(_name, _symbol);
    }

    function tokenURI(uint256) public pure virtual override returns (string memory) {}

    function mint(address to, uint256 tokenId) public virtual {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public virtual {
        _burn(tokenId);
    }

    function safeMint(address to, uint256 tokenId) public virtual {
        _safeMint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId, bytes memory data) public virtual {
        _safeMint(to, tokenId, data);
    }
}

contract MockERC721Test is StdCheats, Test {
    Token_ERC721 token;

    function setUp() public {
        token = new Token_ERC721("Token", "TKN");
    }

    function invariantMetadata() public view {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
    }

    function testMint() public {
        token.mint(address(0xBEEF), 1337);

        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(1337), address(0xBEEF));
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1337);
        token.burn(1337);

        assertEq(token.balanceOf(address(0xBEEF)), 0);

        vm.expectRevert("NOT_MINTED");
        token.ownerOf(1337);
    }

    function testApprove() public {
        token.mint(address(this), 1337);

        token.approve(address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0xBEEF));
    }

    function testApproveBurn() public {
        token.mint(address(this), 1337);

        token.approve(address(0xBEEF), 1337);

        token.burn(1337);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.getApproved(1337), address(0));

        vm.expectRevert("NOT_MINTED");
        token.ownerOf(1337);
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        vm.prank(from);
        token.approve(address(this), 1337);

        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testTransferFromSelf() public {
        token.mint(address(this), 1337);

        token.transferFrom(address(this), address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, 1337);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, 1337);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), 1337, "testing 123");

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertEq(recipient.data(), "testing 123");
    }

    function testSafeMintToEOA() public {
        token.safeMint(address(0xBEEF), 1337);

        assertEq(token.ownerOf(1337), address(address(0xBEEF)));
        assertEq(token.balanceOf(address(address(0xBEEF))), 1);
    }

    function testSafeMintToERC721Recipient() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), 1337);

        assertEq(token.ownerOf(1337), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertEq(to.data(), "");
    }

    function testSafeMintToERC721RecipientWithData() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), 1337, "testing 123");

        assertEq(token.ownerOf(1337), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertEq(to.data(), "testing 123");
    }

    function test_RevertIf_MintToZero() public {
        vm.expectRevert("INVALID_RECIPIENT");
        token.mint(address(0), 1337);
    }

    function test_RevertIf_DoubleMint() public {
        token.mint(address(0xBEEF), 1337);
        vm.expectRevert("ALREADY_MINTED");
        token.mint(address(0xBEEF), 1337);
    }

    function test_RevertIf_BurnUnMinted() public {
        vm.expectRevert("NOT_MINTED");
        token.burn(1337);
    }

    function test_RevertIf_DoubleBurn() public {
        token.mint(address(0xBEEF), 1337);

        token.burn(1337);
        vm.expectRevert("NOT_MINTED");
        token.burn(1337);
    }

    function test_RevertIf_ApproveUnMinted() public {
        vm.expectRevert("NOT_AUTHORIZED");
        token.approve(address(0xBEEF), 1337);
    }

    function test_RevertIf_ApproveUnAuthorized() public {
        token.mint(address(0xCAFE), 1337);

        vm.expectRevert("NOT_AUTHORIZED");
        token.approve(address(0xBEEF), 1337);
    }

    function test_RevertIf_TransferFromUnOwned() public {
        vm.expectRevert("WRONG_FROM");
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_RevertIf_TransferFromWrongFrom() public {
        token.mint(address(0xCAFE), 1337);

        vm.expectRevert("WRONG_FROM");
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_RevertIf_TransferFromToZero() public {
        token.mint(address(this), 1337);

        vm.expectRevert("INVALID_RECIPIENT");
        token.transferFrom(address(this), address(0), 1337);
    }

    function test_RevertIf_TransferFromNotOwner() public {
        token.mint(address(0xFEED), 1337);

        vm.expectRevert("NOT_AUTHORIZED");
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_RevertIf_SafeTransferFromToNonERC721Recipient() public {
        token.mint(address(this), 1337);

        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        token.safeTransferFrom(address(this), nonERC721Recipient, 1337);
    }

    function test_RevertIf_SafeTransferFromToNonERC721RecipientWithData() public {
        token.mint(address(this), 1337);

        address nonERC721Recipient = address(new NonERC721Recipient());

        vm.expectRevert();
        token.safeTransferFrom(address(this), nonERC721Recipient, 1337, "testing123");
    }

    function test_RevertIf_SafeTransferFromToRevertingERC721Recipient() public {
        token.mint(address(this), 1337);

        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeTransferFrom(address(this), revertingERC721Recipient, 1337);
    }

    function test_RevertIf_SafeTransferFromToRevertingERC721RecipientWithData() public {
        token.mint(address(this), 1337);

        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeTransferFrom(address(this), revertingERC721Recipient, 1337, "testing 123");
    }

    function test_RevertIf_SafeTransferFromToERC721RecipientWithWrongReturnData() public {
        token.mint(address(this), 1337);

        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeTransferFrom(address(this), wrongReturnDataERC721Recipient, 1337);
    }

    function test_RevertIf_SafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        token.mint(address(this), 1337);

        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeTransferFrom(address(this), wrongReturnDataERC721Recipient, 1337, "testing123");
    }

    function test_RevertIf_SafeMintToNonERC721Recipient() public {
        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        token.safeMint(nonERC721Recipient, 1337);
    }

    function test_RevertIf_SafeMintToNonERC721RecipientWithData() public {
        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        token.safeMint(nonERC721Recipient, 1337, "testing123");
    }

    function test_RevertIf_SafeMintToRevertingERC721Recipient() public {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeMint(revertingERC721Recipient, 1337);
    }

    function test_RevertIf_SafeMintToRevertingERC721RecipientWithData() public {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeMint(revertingERC721Recipient, 1337, "testing123");
    }

    function test_RevertIf_SafeMintToERC721RecipientWithWrongReturnData() public {
        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeMint(wrongReturnDataERC721Recipient, 1337);
    }

    function test_RevertIf_SafeMintToERC721RecipientWithWrongReturnDataWithData() public {
        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeMint(wrongReturnDataERC721Recipient, 1337, "testing123");
    }

    function test_RevertIf_BalanceOfZeroAddress() public {
        vm.expectRevert("ZERO_ADDRESS");
        token.balanceOf(address(0));
    }

    function test_RevertIf_OwnerOfUnminted() public {
        vm.expectRevert("NOT_MINTED");
        token.ownerOf(1337);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Metadata(string memory name, string memory symbol) public {
        MockERC721 tkn = new Token_ERC721(name, symbol);

        assertEq(tkn.name(), name);
        assertEq(tkn.symbol(), symbol);
    }

    function testFuzz_Mint(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);

        assertEq(token.balanceOf(to), 1);
        assertEq(token.ownerOf(id), to);
    }

    function testFuzz_Burn(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);
        token.burn(id);

        assertEq(token.balanceOf(to), 0);

        vm.expectRevert("NOT_MINTED");
        token.ownerOf(id);
    }

    function testFuzz_Approve(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(address(this), id);

        token.approve(to, id);

        assertEq(token.getApproved(id), to);
    }

    function testFuzz_ApproveBurn(address to, uint256 id) public {
        token.mint(address(this), id);

        token.approve(address(to), id);

        token.burn(id);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.getApproved(id), address(0));

        vm.expectRevert("NOT_MINTED");
        token.ownerOf(id);
    }

    function testFuzz_ApproveAll(address to, bool approved) public {
        token.setApprovalForAll(to, approved);

        assertEq(token.isApprovedForAll(address(this), to), approved);
    }

    function testFuzz_TransferFrom(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        token.mint(from, id);

        vm.prank(from);
        token.approve(address(this), id);

        token.transferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testFuzz_TransferFromSelf(uint256 id, address to) public {
        if (to == address(0) || to == address(this)) to = address(0xBEEF);

        token.mint(address(this), id);

        token.transferFrom(address(this), to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testFuzz_TransferFromApproveAll(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        token.mint(from, id);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testFuzz_SafeTransferFromToEOA(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(from, id);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testFuzz_SafeTransferFromToERC721Recipient(uint256 id) public {
        address from = address(0xABCD);

        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, id);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertEq(recipient.data(), "");
    }

    function testFuzz_SafeTransferFromToERC721RecipientWithData(uint256 id, bytes calldata data) public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, id);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), id, data);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertEq(recipient.data(), data);
    }

    function testFuzz_SafeMintToEOA(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.safeMint(to, id);

        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);
    }

    function testFuzz_SafeMintToERC721Recipient(uint256 id) public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), id);

        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertEq(to.data(), "");
    }

    function testFuzz_SafeMintToERC721RecipientWithData(uint256 id, bytes calldata data) public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), id, data);

        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertEq(to.data(), data);
    }

    function testFuzz_RevertIf_MintToZero(uint256 id) public {
        vm.expectRevert("INVALID_RECIPIENT");
        token.mint(address(0), id);
    }

    function testFuzz_RevertIf_DoubleMint(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);
        vm.expectRevert("ALREADY_MINTED");
        token.mint(to, id);
    }

    function testFuzz_RevertIf_BurnUnMinted(uint256 id) public {
        vm.expectRevert("NOT_MINTED");
        token.burn(id);
    }

    function testFuzz_RevertIf_DoubleBurn(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);

        token.burn(id);
        vm.expectRevert("NOT_MINTED");
        token.burn(id);
    }

    function testFuzz_RevertIf_ApproveUnMinted(uint256 id, address to) public {
        vm.expectRevert("NOT_AUTHORIZED");
        token.approve(to, id);
    }

    function testFuzz_RevertIf_ApproveUnAuthorized(address owner, uint256 id, address to) public {
        if (owner == address(0) || owner == address(this)) owner = address(0xBEEF);

        token.mint(owner, id);

        vm.expectRevert("NOT_AUTHORIZED");
        token.approve(to, id);
    }

    function testFuzz_RevertIf_TransferFromUnOwned(address from, address to, uint256 id) public {
        if (from == address(this) || from == address(0)) from = address(0xBEEF);
        if (to == address(0)) to = address(0xBEEF);

        vm.expectRevert("WRONG_FROM");
        token.transferFrom(from, to, id);
    }

    function testFuzz_RevertIf_TransferFromWrongFrom(address owner, address from, address to, uint256 id) public {
        if (owner == address(0)) owner = address(0xABCD);
        if (to == address(0)) to = address(0xBEEF);
        if (from == owner) revert();

        token.mint(owner, id);

        vm.expectRevert("WRONG_FROM");
        token.transferFrom(from, to, id);
    }

    function testFuzz_RevertIf_TransferFromToZero(uint256 id) public {
        token.mint(address(this), id);

        vm.expectRevert("INVALID_RECIPIENT");
        token.transferFrom(address(this), address(0), id);
    }

    function testFuzz_RevertIf_TransferFromNotOwner(address from, address to, uint256 id) public {
        if (from == address(this) || from == address(0)) from = address(0xBEEF);
        if (to == address(0)) to = address(0xABCD);

        token.mint(from, id);

        vm.expectRevert("NOT_AUTHORIZED");
        token.transferFrom(from, to, id);
    }

    function testFuzz_RevertIf_SafeTransferFromToNonERC721Recipient(uint256 id) public {
        token.mint(address(this), id);

        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        token.safeTransferFrom(address(this), nonERC721Recipient, id);
    }

    function testFuzz_RevertIf_SafeTransferFromToNonERC721RecipientWithData(uint256 id, bytes calldata data) public {
        token.mint(address(this), id);

        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        token.safeTransferFrom(address(this), nonERC721Recipient, id, data);
    }

    function testFuzz_RevertIf_SafeTransferFromToRevertingERC721Recipient(uint256 id) public {
        token.mint(address(this), id);

        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeTransferFrom(address(this), revertingERC721Recipient, id);
    }

    function testFuzz_RevertIf_SafeTransferFromToRevertingERC721RecipientWithData(uint256 id, bytes calldata data)
        public
    {
        token.mint(address(this), id);

        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeTransferFrom(address(this), revertingERC721Recipient, id, data);
    }

    function testFuzz_RevertIf_SafeTransferFromToERC721RecipientWithWrongReturnData(uint256 id) public {
        token.mint(address(this), id);

        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeTransferFrom(address(this), wrongReturnDataERC721Recipient, id);
    }

    function testFuzz_RevertIf_SafeTransferFromToERC721RecipientWithWrongReturnDataWithData(
        uint256 id,
        bytes calldata data
    ) public {
        token.mint(address(this), id);

        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeTransferFrom(address(this), wrongReturnDataERC721Recipient, id, data);
    }

    function testFuzz_RevertIf_SafeMintToNonERC721Recipient(uint256 id) public {
        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        token.safeMint(nonERC721Recipient, id);
    }

    function testFuzz_RevertIf_SafeMintToNonERC721RecipientWithData(uint256 id, bytes calldata data) public {
        address nonERC721Recipient = address(new NonERC721Recipient());
        vm.expectRevert();
        token.safeMint(nonERC721Recipient, id, data);
    }

    function testFuzz_RevertIf_SafeMintToRevertingERC721Recipient(uint256 id) public {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeMint(revertingERC721Recipient, id);
    }

    function testFuzz_RevertIf_SafeMintToRevertingERC721RecipientWithData(uint256 id, bytes calldata data) public {
        address revertingERC721Recipient = address(new RevertingERC721Recipient());
        vm.expectRevert(abi.encodePacked(IERC721TokenReceiver.onERC721Received.selector));
        token.safeMint(revertingERC721Recipient, id, data);
    }

    function testFuzz_RevertIf_SafeMintToERC721RecipientWithWrongReturnData(uint256 id) public {
        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeMint(wrongReturnDataERC721Recipient, id);
    }

    function testFuzz_RevertIf_SafeMintToERC721RecipientWithWrongReturnDataWithData(uint256 id, bytes calldata data)
        public
    {
        address wrongReturnDataERC721Recipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeMint(wrongReturnDataERC721Recipient, id, data);
    }

    function testFuzz_RevertIf_OwnerOfUnminted(uint256 id) public {
        vm.expectRevert("NOT_MINTED");
        token.ownerOf(id);
    }
}
