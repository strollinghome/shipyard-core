// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {ExampleNFT} from "src/reference/ExampleNFT.sol";
import {DynamicTraits} from "src/dynamic-traits/ERC721OnchainTraits.sol";
import {
    TraitLabelStorage,
    TraitLabelStorageLib,
    TraitLabel,
    TraitLabelLib,
    FullTraitValue,
    StoredTraitLabel,
    TraitLib,
    StoredTraitLabelLib
} from "src/dynamic-traits/lib/TraitLabelLib.sol";
import {DisplayType} from "src/onchain/Metadata.sol";

contract Debug is ExampleNFT("Example", "EXNFT") {
    function getStringURI(uint256 tokenId) public view returns (string memory) {
        return _stringURI(tokenId);
    }
}

contract ERC721OnchainTraitsTest is Test {
    Debug token;

    function setUp() public {
        token = new Debug();
    }

    function testGetTraitLabel() public {
        TraitLabel memory label = _setLabel();
        TraitLabelStorage memory storage_ = token.traitLabelStorage(bytes32("testKey"));
        assertEq(storage_.valuesRequireValidation, false);
        TraitLabel memory retrieved = StoredTraitLabelLib.load(storage_.storedLabel);
        assertEq(label, retrieved);
    }

    function testGetTraitLabelsURI() public {
        _setLabel();
        assertEq(
            token.getTraitMetadataURI(),
            'data:application/json;[{"traitKey":"testKey","fullTraitKey":"testKey","traitLabel":"Trait Key","acceptableValues":[],"fullTraitValues":[],"displayType":"string"}]'
        );
    }

    function testSetTrait() public {
        _setLabel();
        token.mint(address(this));
        token.setTrait(1, bytes32("testKey"), bytes32("foo"));
        assertEq(token.getTraitValue(1, bytes32("testKey")), bytes32("foo"));
    }

    function testStringURI() public {
        _setLabel();
        token.mint(address(this));
        token.setTrait(1, bytes32("testKey"), bytes32("foo"));
        assertEq(token.getTraitValue(1, bytes32("testKey")), bytes32("foo"));
        assertEq(
            token.getStringURI(1),
            '{"name":"Example NFT #1","description":"This is an example NFT","image":"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MDAiIGhlaWdodD0iNTAwIiA+PHJlY3Qgd2lkdGg9IjUwMCIgaGVpZ2h0PSI1MDAiIGZpbGw9ImxpZ2h0Z3JheSIgLz48dGV4dCB4PSI1MCUiIHk9IjUwJSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSI0OCIgZmlsbD0iYmxhY2siID4xPC90ZXh0Pjwvc3ZnPg==","attributes":[{"trait_type":"Example Attribute","value":"Example Value"},{"trait_type":"Number","value":"1","display_type":"number"},{"trait_type":"Parity","value":"Odd"},{"trait_type":"Trait Key","value":"foo","display_type":"string"}]}'
        );
    }

    function _setLabel() internal returns (TraitLabel memory) {
        TraitLabel memory label = TraitLabel({
            fullTraitKey: "",
            traitLabel: "Trait Key",
            acceptableValues: new string[](0),
            fullTraitValues: new FullTraitValue[](0),
            displayType: DisplayType.String
        });
        token.setTraitLabel(bytes32("testKey"), label);
        return label;
    }

    function assertEq(TraitLabel memory a, TraitLabel memory b) internal {
        assertEq(a.fullTraitKey, b.fullTraitKey, "fullTraitKey");
        assertEq(a.traitLabel, b.traitLabel, "traitLabel");
        assertEq(keccak256(abi.encode(a.acceptableValues)), keccak256(abi.encode(b.acceptableValues)));
        assertEq(keccak256(abi.encode(a.fullTraitValues)), keccak256(abi.encode(b.fullTraitValues)));
        assertEq(uint8(a.displayType), uint8(b.displayType), "displayType");
    }

    function testBytes32ToString() public {
        string memory x = TraitLib.asString(bytes32("foo"));
        assertEq(x, "foo");
        x = TraitLib.asString(bytes32("a string that's exactly 32 chars"));
        assertEq(x, "a string that's exactly 32 chars");
    }
}
