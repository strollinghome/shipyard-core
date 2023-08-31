// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DynamicTraits} from "./DynamicTraits.sol";
import {
    TraitLabel,
    AllowedEditor,
    Editors,
    TraitLabelLib,
    TraitLabelStorageLib,
    TraitLabelStorage,
    StoredTraitLabel,
    toBitMap
} from "./lib/TraitLabelLib.sol";
import {Metadata} from "shipyard-core/onchain/Metadata.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SSTORE2} from "solady/utils/SSTORE2.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

abstract contract OnchainTraits is Ownable, DynamicTraits {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using {toBitMap} for AllowedEditor;
    using TraitLabelStorageLib for mapping(bytes32 => TraitLabelStorage);
    using TraitLabelStorageLib for TraitLabelStorage;
    using TraitLabelLib for TraitLabel;

    error InsufficientPrivilege();
    error TraitDoesNotExist(bytes32 traitKey);

    ///@notice a mapping of traitKey to SSTORE2 storage addresses
    mapping(bytes32 traitKey => TraitLabelStorage traitLabelStorage) public traitLabelStorage;
    EnumerableSet.AddressSet internal _customEditors;

    // ABSTRACT

    ///@notice helper to determine if a given address has the AllowedEditor.TokenOwner privilege
    function isOwnerOrApproved(uint256 tokenId, address addr) internal view virtual returns (bool);

    // CUSTOM EDITORS

    function isCustomEditor(address editor) external view returns (bool) {
        return _customEditors.contains(editor);
    }

    function updateCustomEditor(address editor, bool insert) external onlyOwner {
        if (insert) {
            _customEditors.add(editor);
        } else {
            _customEditors.remove(editor);
        }
    }

    function getCustomEditors() external view returns (address[] memory) {
        return _customEditors.values();
    }

    function getCustomEditorsLength() external view returns (uint256) {
        return _customEditors.length();
    }

    function getCustomEditorAt(uint256 index) external view returns (address) {
        return _customEditors.at(index);
    }

    // LABELS URI

    function getTraitLabelsURI() external view virtual override returns (string memory) {
        return Metadata.jsonDataURI(getTraitLabelsJson());
    }

    function getTraitLabelsJson() internal view returns (string memory) {
        bytes32[] memory keys = _traitKeys.values();
        return traitLabelStorage.toLabelJson(keys);
    }

    error TraitIsRequired();

    function setTrait(bytes32 traitKey, uint256 tokenId, bytes32 trait, bool clear) external virtual {
        TraitLabelStorage memory labelStorage = traitLabelStorage[traitKey];
        StoredTraitLabel storedTraitLabel = labelStorage.storedLabel;
        if (!storedTraitLabel.exists()) {
            revert TraitDoesNotExist(traitKey);
        }
        _verifySetterPrivilege(labelStorage.allowedEditors, tokenId);
        if (clear) {
            if (labelStorage.required) {
                revert TraitIsRequired();
            } else {
                _setTrait(traitKey, tokenId, bytes32(0), true);
                return;
            }
        }
        if (labelStorage.valuesRequireValidation) {
            storedTraitLabel.load().validateAcceptableValue(traitKey, trait);
        }
        _setTrait(traitKey, tokenId, trait, false);
    }

    function setTraitLabel(bytes32 traitKey, TraitLabel calldata _traitLabel) external virtual onlyOwner {
        _setTraitLabel(traitKey, _traitLabel);
    }

    function _setTraitLabel(bytes32 traitKey, TraitLabel memory _traitLabel) internal virtual {
        _traitKeys.add(traitKey);
        traitLabelStorage[traitKey] = TraitLabelStorage({
            allowedEditors: _traitLabel.editors,
            required: _traitLabel.required,
            valuesRequireValidation: _traitLabel.acceptableValues.length > 0,
            storedLabel: _traitLabel.store()
        });
    }

    function _verifySetterPrivilege(Editors editors, uint256 tokenId) internal view {
        // anyone
        if (editors.contains(AllowedEditor.Anyone)) {
            // short circuit
            return;
        }
        if (editors.contains(AllowedEditor.Self)) {}

        // tokenOwner
        if (editors.contains(AllowedEditor.TokenOwner)) {
            if (isOwnerOrApproved(tokenId, msg.sender)) {
                // short circuit
                return;
            }
        }
        // customEditor
        if (editors.contains(AllowedEditor.Custom)) {
            if (_customEditors.contains(msg.sender)) {
                // short circuit
                return;
            }
        }
        // contractOwner
        if (editors.contains(AllowedEditor.ContractOwner)) {
            if (owner() == msg.sender) {
                // short circuit
                return;
            }
        }

        revert InsufficientPrivilege();
    }

    function _dynamicAttributes(uint256 tokenId) internal view returns (string[] memory) {
        bytes32[] memory keys = _traitKeys.values();
        uint256 keysLength = keys.length;

        string[] memory attributes = new string[](keysLength);
        uint256 num;
        for (uint256 i = 0; i < keysLength;) {
            bytes32 key = keys[i];
            bytes32 trait = _traits[tokenId][key];
            if (trait != bytes32(0)) {
                if (trait == ZERO_VALUE) {
                    trait = bytes32(0);
                }
                attributes[num] = traitLabelStorage.toAttributeJson(key, trait);
                unchecked {
                    ++num;
                }
            }
            unchecked {
                ++i;
            }
        }
        ///@solidity memory-safe-assembly
        assembly {
            // update attributes with actual length
            mstore(attributes, num)
        }

        return attributes;
    }
}
