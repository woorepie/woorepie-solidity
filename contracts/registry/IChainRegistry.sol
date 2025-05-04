// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IChainRegistry {
    // Enums
    enum IdentityStatus {
        NONE,
        VERIFIED,
        EXPIRED
    }

    // Structs
    struct Identity {
        bool isVerified;
        uint256 validUntil;
        bytes32 verificationHash;
        IdentityStatus status;
    }

    struct SyncData {
        uint256 lastSyncTimestamp;
        bytes32 syncHash;
        string syncUri;
    }

    // Events
    event IdentityVerified(address indexed user, bytes32 verificationHash);
    event IdentitySynced(address indexed user, bytes32 syncHash, uint256 timestamp);
    event IdentityStatusUpdated(address indexed user, IdentityStatus status);

    // Core Functions
    function verifyIdentity(
        address user,
        bytes32 verificationHash,
        uint256 validityPeriod,
        bytes memory signature
    ) external;

    function syncIdentity(
        address user,
        bytes32 newSyncHash,
        string calldata syncUri
    ) external;

    function getIdentityStatus(address user) external view returns (
        bool isValid,
        IdentityStatus status,
        uint256 validUntil,
        uint256 lastSync
    );

    function updateIdentityStatus(
        address user,
        IdentityStatus newStatus
    ) external;

    // Admin Functions
    function pause() external;
    function unpause() external;
}