// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol"; 
import "@openzeppelin/contracts/security/Pausable.sol"; // Pausable 추가
import "./registry/IChainRegistry.sol";
import "./ERC1400.sol";



contract WooreToken is ERC1400, Pausable, AccessControl{
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    bytes32 public constant KYC_ROLE = keccak256("KYC_ROLE");

    IChainRegistry public identityRegistry;

    
    // KYC 상태 관리
    mapping(address => bool) private kycPassed;
    
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
        address(0), // certificateSigner - 기본값으로 0 주소 사용
        false,      // certificateActivated - 기본값으로 false 사용
        defaultPartitions
    ) {
        identityRegistry = IChainRegistry(registryAddress);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(KYC_ROLE, msg.sender);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    
    // KYC 관련 함수
    function setKYCStatus(address account, bool status) 
        external 
        onlyRole(KYC_ROLE) 
    {
        kycPassed[account] = status;
        emit KYCStatusChanged(account, status);
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
    ) internal{
        require(!paused(), "Token transfers are paused");
        
        // mint와 burn은 KYC 체크에서 제외
        if (from != address(0) && to != address(0)) {
            require(kycPassed[from], "Sender KYC not passed");
            require(kycPassed[to], "Receiver KYC not passed");
            require(!frozen[from], "Sender account is frozen");
            require(!frozen[to], "Receiver account is frozen");
        }
    }
    
    // ERC3643에서 영감을 받은 추가 기능들
    function isVerified(address account) public view returns (bool) {
        return kycPassed[account];
    }
    
    function isFrozen(address account) public view returns (bool) {
        return frozen[account];
    }


    function _validateTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view returns (bool, bytes1, bytes32) {
        // Identity 검증
        (bool isValid,,,) = identityRegistry.getIdentityStatus(from);

        if (!isValid) {
            return (false, 0x55, "User not verified");
        }

        return (true, 0x51, "");  // Transfer success
    }

    
    // Events
    event KYCStatusChanged(address indexed account, bool status);
    event FrozenStatusChanged(address indexed account, bool status);
    event DocumentUpdated(string documentURI, bytes32 documentHash);
}


