// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ChainRegistry is AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // 1. 중앙화 검증 데이터 구조
    struct Identity {
        bool isVerified;
        uint256 validUntil;
        bytes32 verificationHash;
        IdentityStatus status;
    }

    // 3. 동기화 데이터 구조
    struct SyncData {
        uint256 lastSyncTimestamp;
        bytes32 syncHash;
        string syncUri;
    }

    // 통합 상태 관리
    enum IdentityStatus {
        NONE,
        VERIFIED,
        EXPIRED
    }

    // 매핑
    mapping(address => Identity) public identities;
    mapping(address => SyncData) public syncData;
    mapping(bytes32 => bool) public usedSignatures;

    // 이벤트
    event IdentityVerified(address indexed user, bytes32 verificationHash);
    event IdentitySynced(address indexed user, bytes32 syncHash, uint256 timestamp);
    event IdentityStatusUpdated(address indexed user, IdentityStatus status);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(VERIFIER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    // 중앙화 검증 기능
    function verifyIdentity(
        address user,
        bytes32 verificationHash,
        uint256 validityPeriod,
        bytes memory signature
    ) external whenNotPaused onlyRole(VERIFIER_ROLE) {
        require(!usedSignatures[keccak256(signature)], "Signature already used");
        
        // 서명 검증
        bytes32 messageHash = keccak256(abi.encode(user, verificationHash, validityPeriod));
        require(isValidSignature(messageHash, signature), "Invalid signature");

        identities[user] = Identity({
            isVerified: true,
            validUntil: block.timestamp + validityPeriod,
            verificationHash: verificationHash,
            status: IdentityStatus.VERIFIED
        });

        usedSignatures[keccak256(signature)] = true;
        emit IdentityVerified(user, verificationHash);
    }

    // 동기화 기능
    function syncIdentity(
        address user,
        bytes32 newSyncHash,
        string calldata syncUri
    ) external whenNotPaused onlyRole(ADMIN_ROLE) {
        require(identities[user].isVerified, "Identity not verified");

        syncData[user] = SyncData({
            lastSyncTimestamp: block.timestamp,
            syncHash: newSyncHash,
            syncUri: syncUri
        });

        emit IdentitySynced(user, newSyncHash, block.timestamp);
    }

    // 상태 조회 및 검증 기능
    function getIdentityStatus(address user) external view returns (
        bool isValid,
        IdentityStatus status,
        uint256 validUntil,
        uint256 lastSync
    ) {
        Identity memory identity = identities[user];
        SyncData memory sync = syncData[user];
        
        return (
            identity.isVerified && block.timestamp <= identity.validUntil,
            identity.status,
            identity.validUntil,
            sync.lastSyncTimestamp
        );
    }

    // 서명 검증 헬퍼 함수 (수정됨)
    function isValidSignature(
        bytes32 messageHash,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 prefixedHash = messageHash.toEthSignedMessageHash();
        address signer = prefixedHash.recover(signature);
        return hasRole(VERIFIER_ROLE, signer);
    }

    // 관리 기능
    function updateIdentityStatus(
        address user,
        IdentityStatus newStatus
    ) external onlyRole(ADMIN_ROLE) {
        identities[user].status = newStatus;
        emit IdentityStatusUpdated(user, newStatus);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}