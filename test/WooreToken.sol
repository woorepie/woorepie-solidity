// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./registry/IChainRegistry.sol";
import "./ERC1400.sol";

contract WooreToken is ERC1400, Pausable, AccessControl {
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    IChainRegistry public identityRegistry;

    // 전송 제한 상태
    mapping(address => bool) private frozen;

    // 기본적인 문서 참조 (ERC1400 스타일)
    string private _documentURI;
    bytes32 private _documentHash;

    constructor(
        string memory name,
        string memory symbol,
        uint256 granularity,
        address[] memory controllers,
        bytes32[] memory defaultPartitions,
        address registryAddress
    ) ERC1400(
        name,
        symbol,
        granularity,
        controllers,
        address(0), // certificateSigner
        false,      // certificateActivated
        defaultPartitions
    ) {
        identityRegistry = IChainRegistry(registryAddress);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // 계정 동결/해제
    function setFrozen(address account, bool status)
        external
        onlyRole(ADMIN_ROLE)
    {
        frozen[account] = status;
        emit FrozenStatusChanged(account, status);
    }

    // 체인 ID 반환
    function getChainId() public view returns (uint256) {
        return block.chainid;
    }

    // 전송 제한 로직
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(!paused(), "Token transfers are paused");

        // mint, burn은 제외
        if (from != address(0) && to != address(0)) {
            (bool fromVerified,,,) = identityRegistry.getIdentityStatus(from);
            (bool toVerified,,,) = identityRegistry.getIdentityStatus(to);

            require(fromVerified, "Sender not KYC verified");
            require(toVerified, "Receiver not KYC verified");
            require(!frozen[from], "Sender is frozen");
            require(!frozen[to], "Receiver is frozen");
        }
    }

    // 동결 여부 확인
    function isFrozen(address account) public view returns (bool) {
        return frozen[account];
    }

    // 전송 유효성 검증 (오프체인에서 확인 용도)
    function validateTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool success, bytes1 code, bytes32 reason) {
        (bool fromVerified,,,) = identityRegistry.getIdentityStatus(from);
        (bool toVerified,,,) = identityRegistry.getIdentityStatus(to);

        if (!fromVerified || !toVerified) {
            return (false, 0x55, "Sender or receiver not verified");
        }
        if (frozen[from] || frozen[to]) {
            return (false, 0x56, "Sender or receiver frozen");
        }
        if (paused()) {
            return (false, 0x57, "Token is paused");
        }

        return (true, 0x51, "Validated");
    }

    // 이벤트
    event FrozenStatusChanged(address indexed account, bool status);
    event DocumentUpdated(string documentURI, bytes32 documentHash);
}
