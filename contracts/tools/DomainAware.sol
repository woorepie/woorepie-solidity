// SPDX-License-Identifier: Apache-2.0
// Copyright 2020 ConsenSys Software Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitation
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.28;

abstract contract DomainAware {

    // Mapping of ChainID to domain separators. This is a very gas efficient way
    // to not recalculate the domain separator on every call, while still
    // automatically detecting ChainID changes.
    mapping(uint256 => bytes32) private domainSeparators;

    constructor() {
        _updateDomainSeparator();
    }

    function domainName() public virtual view returns (string memory);

    function domainVersion() public virtual view returns (string memory);

    function generateDomainSeparator() public view returns (bytes32) {
        uint256 chainID = _chainID();

        // no need for assembly, running very rarely
        bytes32 domainSeparatorHash = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(domainName())), // ERC-20 Name
                keccak256(bytes(domainVersion())), // Version
                chainID,
                address(this)
            )
        );

        return domainSeparatorHash;
    }

    function domainSeparator() public returns (bytes32) {
        return _domainSeparator();
    }

    function _updateDomainSeparator() private returns (bytes32) {
        uint256 chainID = _chainID();

        bytes32 newDomainSeparator = generateDomainSeparator();

        domainSeparators[chainID] = newDomainSeparator;

        return newDomainSeparator;
    }

    // Returns the domain separator, updating it if chainID changes
    function _domainSeparator() private returns (bytes32) {
        bytes32 currentDomainSeparator = domainSeparators[_chainID()];

        if (currentDomainSeparator != 0x00) {
            return currentDomainSeparator;
        }

        return _updateDomainSeparator();
    }

    function _chainID() internal view returns (uint256) {
        uint256 chainID;
        assembly {
            chainID := chainid()
        }

        return chainID;
    }
}