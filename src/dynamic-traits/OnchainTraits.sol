// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DynamicTraits} from "./DynamicTraits.sol";
import {Metadata} from "../onchain/Metadata.sol";
import {SSTORE2} from "solady/src/utils/SSTORE2.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {
    TraitLabelStorage,
    TraitLabelStorageLib,
    TraitLabel,
    TraitLabelLib,
    StoredTraitLabel,
    StoredTraitLabelLib
} from "./lib/TraitLabelLib.sol";

library OnchainTraitsStorage {
    struct Layout {
        /// @notice An enumerable set of all trait keys that have been set.
        EnumerableSet.Bytes32Set _traitKeys;
        /// @notice A mapping of traitKey to OnchainTraitsStorage.layout()._traitLabelStorage metadata.
        mapping(bytes32 traitKey => TraitLabelStorage traitLabelStorage) _traitLabelStorage;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("contracts.storage.erc7496-dynamictraits.onchaintraits");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract OnchainTraits is DynamicTraits {
    using OnchainTraitsStorage for OnchainTraitsStorage.Layout;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Thrown when trying to set a trait that does not exist
    error TraitDoesNotExist(bytes32 traitKey);

    /**
     * @notice Get the onchain URI for the trait metadata, encoded as a JSON data URI
     */
    function getTraitMetadataURI() external view virtual override returns (string memory) {
        return Metadata.jsonDataURI(_getTraitMetadataJson());
    }

    /**
     * @notice Get the raw JSON for the trait metadata
     */
    function _getTraitMetadataJson() internal view returns (string memory) {
        bytes32[] memory keys = OnchainTraitsStorage.layout()._traitKeys.values();
        return TraitLabelStorageLib.toLabelJson(OnchainTraitsStorage.layout()._traitLabelStorage, keys);
    }

    /**
     * @notice Return trait label storage information at a given key.
     */
    function traitLabelStorage(bytes32 traitKey) external view returns (TraitLabelStorage memory) {
        return OnchainTraitsStorage.layout()._traitLabelStorage[traitKey];
    }

    /**
     * @notice Set a trait for a given traitKey and tokenId. If the TraitLabel specifies that the trait
     *         value must be validated, checks that the trait value is valid.
     * @param tokenId The token ID to get the trait value for
     * @param traitKey The trait key to get the value of
     * @param newValue The new trait value
     */
    function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 newValue) public virtual override {
        TraitLabelStorage memory labelStorage = OnchainTraitsStorage.layout()._traitLabelStorage[traitKey];
        StoredTraitLabel storedTraitLabel = labelStorage.storedLabel;
        if (!StoredTraitLabelLib.exists(storedTraitLabel)) {
            revert TraitDoesNotExist(traitKey);
        }

        if (labelStorage.valuesRequireValidation) {
            TraitLabelLib.validateAcceptableValue(StoredTraitLabelLib.load(storedTraitLabel), traitKey, newValue);
        }
        DynamicTraits.setTrait(tokenId, traitKey, newValue);
    }

    /**
     * @notice Set the OnchainTraitsStorage.layout()._traitLabelStorage for a traitKey. Packs SSTORE2 value along with required?, and
     *         valuesRequireValidation? into a single storage slot for more efficient validation when setting trait values.
     */
    function _setTraitLabel(bytes32 traitKey, TraitLabel memory _traitLabel) internal virtual {
        OnchainTraitsStorage.layout()._traitKeys.add(traitKey);
        OnchainTraitsStorage.layout()._traitLabelStorage[traitKey] = TraitLabelStorage({
            required: _traitLabel.required,
            valuesRequireValidation: _traitLabel.acceptableValues.length > 0,
            storedLabel: TraitLabelLib.store(_traitLabel)
        });
    }

    /**
     * @notice Gets the individual JSON objects for each dynamic trait set on this token by iterating over all
     *         possible traitKeys and checking if the trait is set on the token. This is extremely inefficient
     *         and should only be called offchain when rendering metadata.
     * @param tokenId The token ID to get the dynamic trait attributes for
     * @return An array of JSON objects, each representing a dynamic trait set on the token
     */
    function _dynamicAttributes(uint256 tokenId) internal view virtual returns (string[] memory) {
        bytes32[] memory keys = OnchainTraitsStorage.layout()._traitKeys.values();
        uint256 keysLength = keys.length;

        string[] memory attributes = new string[](keysLength);
        // keep track of how many traits are actually set
        uint256 num;
        for (uint256 i = 0; i < keysLength;) {
            bytes32 key = keys[i];
            bytes32 trait = getTraitValue(tokenId, key);
            // check that the trait is set, otherwise, skip it
            if (trait != bytes32(0)) {
                attributes[num] =
                    TraitLabelStorageLib.toAttributeJson(OnchainTraitsStorage.layout()._traitLabelStorage, key, trait);
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
