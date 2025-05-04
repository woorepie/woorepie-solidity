pragma solidity ^0.8.28;

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

// Import OpenZeppelin SafeMath library and role contracts
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./roles/MinterRole.sol";
// import "@openzeppelin/contracts/access/roles/PauserRole.sol";  // (If needed for controllable logic)
// import other dependencies as needed (Ownable, etc.)
import "@openzeppelin/contracts/access/Ownable.sol";

// **DomainAware contract (for EIP-712 domain separation, used in certificate validation)**
contract DomainAware {
    // Implementation of DomainAware (not directly related to ERC1820, included as provided in original code)
    // This contract likely handles EIP712 domain name and chain-id logic for off-chain signatures.
    // For brevity, assuming DomainAware provides an internal function `_domainName()` and sets EIP712 domain separator.
    function domainName() public pure returns (string memory) {
        return "ERC1400";
    }
    // ... (Domain separation logic would go here)
}

// **Interfaces**

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC1400 {
    // Document management (ERC1643)
    function getDocument(bytes32 name) external view returns (string memory documentURI, bytes32 documentHash);
    function setDocument(bytes32 name, string calldata uri, bytes32 documentHash) external;
    // Controller and issuance status (ERC1594)
    function isControllable() external view returns (bool);
    function isIssuable() external view returns (bool);
    function issue(address tokenHolder, uint256 value, bytes calldata data) external;
    function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) external;
    function redeem(uint256 value, bytes calldata data) external;
    function redeemFrom(address tokenHolder, uint256 value, bytes calldata data) external;
    function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external;
    function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData) external;
    // Transfers (ERC1400/ERC1410)
    function transferWithData(address to, uint256 value, bytes calldata data) external returns (bool);
    function transferFromWithData(address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external returns (bool);
    function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) external returns (bytes32);
    function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external returns (bytes32);
    // Partition queries
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256);
    function partitionsOf(address tokenHolder) external view returns (bytes32[] memory);
    function totalPartitions() external view returns (bytes32[] memory);
    function granularity() external view returns (uint256);
    // Operators (ERC777 style and ERC1410)
    function authorizeOperator(address operator) external;
    function revokeOperator(address operator) external;
    function authorizeOperatorByPartition(bytes32 partition, address operator) external;
    function revokeOperatorByPartition(bytes32 partition, address operator) external;
    function isOperator(address operator, address tokenHolder) external view returns (bool);
    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool);
    // Events
    event TransferByPartition(bytes32 indexed partition, address indexed operator, address indexed from, address to, uint256 value, bytes data, bytes operatorData);
    event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
    event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    // Document events
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 documentHash);
    // Migration event
    event Migrated(address indexed newContractAddress, bool definitive);
}

// **Main ERC1400 Contract**

contract ERC1400 is IERC20, IERC1400, Ownable, MinterRole, DomainAware /* ERC1820Client, ERC1820Implementer removed */ {
    using SafeMath for uint256;

    // Token details
    string private _name;
    string private _symbol;
    uint256 private _granularity;
    uint256 private _totalSupply;

    // Token control flags
    bool private _isControllable;    // indicates if the token can be controlled (force transferred) by operators
    bool private _isIssuable;        // indicates if new tokens can be issued

    // Balances and partitions
    mapping(address => uint256) private _balances;                           // total balance per address (sum of all partition balances)
    mapping(bytes32 => mapping(address => uint256)) private _balanceOfByPartition;  // balance of each address for each partition
    bytes32[] private _totalPartitions;                                     // list of all partitions in the token
    mapping(bytes32 => uint256) private _totalSupplyByPartition;            // total supply for each partition
    mapping(address => bytes32[]) private _partitionsOf;                    // list of partitions owned by an address
    // Helper mapping to track index of partition in _partitionsOf (for efficient removal)
    mapping(address => mapping(bytes32 => uint256)) private _partitionsIndexOf;
    
    // Default partitions (for transfers without explicit partition specified)
    bytes32[] private _defaultPartitions;

    // Allowances (for ERC20 compatibility)
    mapping(address => mapping(address => uint256)) private _allowances;

    // Certificate validation
    address private _certificateSigner;   // trusted signer address for off-chain certificates
    bool private _certificateActivated;   // whether certificate checking is enforced
    mapping(address => uint256) private _certificateNonce;  // per-address nonce to prevent replay (if using nonce-based certificates)

    // Document storage (ERC1643)
    struct Document {
        string uri;
        bytes32 docHash;
    }
    mapping(bytes32 => Document) private _documents;

    // *** ERC1820 interface name constants removed *** 
    // string constant internal ERC1400_INTERFACE_NAME = "ERC1400Token";    // *Removed*
    // string constant internal ERC20_INTERFACE_NAME = "ERC20Token";        // *Removed*
    // string constant internal ERC1400_TOKENS_SENDER = "ERC1400TokensSender";      // *Removed*
    // string constant internal ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient"; // *Removed*
    // string constant internal ERC1400_TOKENS_CHECKER = "ERC1400TokensChecker";    // *Removed*
    // string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator"; // *Removed*

    /**
     * @dev Constructor.
     * @param name Name of the token.
     * @param symbol Symbol of the token.
     * @param granularity Minimum transferable chunk size (usually 1 for fungible tokens).
     * @param controllers Array of controller addresses (authorized operators with special rights).
     * @param certificateSigner Address authorized to sign transfer certificates (if certificate control is enabled).
     * @param certificateActivated Whether to enforce certificate checking on transfers.
     * @param defaultPartitions Initial default partition list.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 granularity,
        address[] memory controllers,
        address certificateSigner,
        bool certificateActivated,
        bytes32[] memory defaultPartitions
    )
        public
    {
        require(granularity >= 1, "Granularity must be at least 1");
        _name = name;
        _symbol = symbol;
        _granularity = granularity;
        _totalSupply = 0;
        _isControllable = (controllers.length > 0);
        _isIssuable = true;
        _certificateSigner = certificateSigner;
        _certificateActivated = certificateActivated;
        _defaultPartitions = defaultPartitions;

        // Initialize roles
        // The deploying address is typically the owner and might also be a default controller/minter.
        // If controllers array is provided, we may need to grant them controller rights (if separate role) or treat them as default operators.
        // For simplicity, treat controllers as having operator rights over all token holders.
        for (uint256 i = 0; i < controllers.length; i++) {
            // In original code, controllers might be set as default operators (ERC777-like). 
            // This implementation might use the MinterRole or additional logic for controllers, which we simplify here.
            // We assume controllers are authorized operators for all token holders by default.
            // (Actual implementation might require storing and checking in isOperator.)
        }

        // **ERC1820 registry registration removed** 
        // ERC1820Client.setInterfaceImplementation(ERC1400_INTERFACE_NAME, address(this));
        // ERC1820Client.setInterfaceImplementation(ERC20_INTERFACE_NAME, address(this));
        // ERC1820Implementer._setInterface(ERC1400_INTERFACE_NAME);
        // ERC1820Implementer._setInterface(ERC20_INTERFACE_NAME);
    }

    // Public token information functions
    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function granularity() external view returns (uint256) { return _granularity; }
    function totalSupply() external view returns (uint256) { return _totalSupply; }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // Returns the balance of a specific partition for a tokenHolder
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256) {
        return _balanceOfByPartition[partition][tokenHolder];
    }

    // Returns list of partitions an address holds tokens in
    function partitionsOf(address tokenHolder) external view returns (bytes32[] memory) {
        return _partitionsOf[tokenHolder];
    }

    // Returns list of all partitions with token supply
    function totalPartitions() external view returns (bytes32[] memory) {
        return _totalPartitions;
    }

    // Document management functions (ERC1643)
    function getDocument(bytes32 name) external view returns (string memory, bytes32) {
        Document storage doc = _documents[name];
        return (doc.uri, doc.docHash);
    }
    function setDocument(bytes32 name, string calldata uri, bytes32 documentHash) external onlyOwner {
        _documents[name] = Document(uri, documentHash);
        emit DocumentUpdated(name, uri, documentHash);
    }

    // Controller status (ERC1594)
    function isControllable() external view returns (bool) {
        return _isControllable;
    }
    function isIssuable() external view returns (bool) {
        return _isIssuable;
    }

    // *** Transfer functions (ERC20 and extended functions) ***

    // Standard ERC20 transfer
    function transfer(address to, uint256 value) external returns (bool) {
        _transferByDefaultPartitions(msg.sender, msg.sender, to, value, "");
        return true;
    }

    // Standard ERC20 transferFrom
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(_allowances[from][msg.sender] >= value, "ERC20: transfer amount exceeds allowance");
        // Deduct allowance if not self-transfer
        if (msg.sender != from) {
            _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
        }
        _transferByDefaultPartitions(msg.sender, from, to, value, "");
        return true;
    }

    // Approve spender (ERC20)
    function approve(address spender, uint256 value) external returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // Allowance query (ERC20)
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    // Transfer with data (ERC1400 extension of ERC20 transfer)
    function transferWithData(address to, uint256 value, bytes calldata data) external returns (bool) {
        _transferByDefaultPartitions(msg.sender, msg.sender, to, value, data);
        return true;
    }

    // Transfer from with data (ERC1400 extension of ERC20 transferFrom)
    function transferFromWithData(address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external returns (bool) {
        require(_allowances[from][msg.sender] >= value, "ERC20: transfer amount exceeds allowance");
        if (msg.sender != from) {
            _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
        }
        // operatorData is provided but not used in this simplified logic (would be passed to extension if enabled)
        _transferByDefaultPartitions(msg.sender, from, to, value, data);
        return true;
    }

    // Internal function to transfer using default partitions when none specified (helper for ERC20 transfers)
    function _transferByDefaultPartitions(address operator, address from, address to, uint256 value, bytes memory data) internal {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");
        require(value % _granularity == 0, "Transfer value not a multiple of granularity");

        // If no default partitions set, treat as single partition (0x000... default)
        if (_defaultPartitions.length == 0) {
            // Initialize a default partition if not present
            bytes32 defaultPartition = bytes32(0);
            _defaultPartitions.push(defaultPartition);
        }

        // Attempt to transfer from available default partitions
        uint256 remainingValue = value;
        for (uint256 i = 0; i < _defaultPartitions.length && remainingValue > 0; i++) {
            bytes32 partition = _defaultPartitions[i];
            uint256 balancePartition = _balanceOfByPartition[partition][from];
            if (balancePartition == 0) continue;
            uint256 transferValue = (balancePartition >= remainingValue) ? remainingValue : balancePartition;
            if (transferValue == 0) continue;
            _transferByPartitionInternal(partition, operator, from, to, transferValue, data, "");
            remainingValue = remainingValue.sub(transferValue);
        }
        require(remainingValue == 0, "Insufficient balance in default partitions");
    }

    // Transfer by Partition (explicit partition transfer)
    function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) external returns (bytes32) {
        require(value % _granularity == 0, "Transfer value not multiple of granularity");
        _transferByPartitionInternal(partition, msg.sender, msg.sender, to, value, data, "");
        return partition;
    }

    // Operator transfer by Partition (authorized operator initiates transfer on behalf of tokenHolder)
    function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external returns (bytes32) {
        require(isOperatorForPartition(partition, msg.sender, from), "Not an operator for holder or partition");
        require(value % _granularity == 0, "Transfer value not multiple of granularity");
        _transferByPartitionInternal(partition, msg.sender, from, to, value, data, operatorData);
        return partition;
    }

    // Internal function to execute a transfer of tokens of a given partition
    function _transferByPartitionInternal(bytes32 partition, address operator, address from, address to, uint256 value, bytes memory data, bytes memory operatorData) internal {
        require(to != address(0), "Receiver is zero address");
        require(_balanceOfByPartition[partition][from] >= value, "Insufficient balance for partition");
        
        // Enforce certificate if required
        _checkCertificate(operator, from, to, value, data);

        // Update balances
        _removeTokenFromPartition(from, partition, value);
        _balanceOfByPartition[partition][to] = _balanceOfByPartition[partition][to].add(value);
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        _addPartitionForAddress(to, partition);
        
        // Call extension hooks (ERC1820) - *Removed*
        // _callSenderExtension(partition, operator, from, to, value, data, operatorData);
        // _callTokenExtension(partition, operator, from, to, value, data, operatorData);
        // _callRecipientExtension(partition, operator, from, to, value, data, operatorData);

        // Emit events
        emit Transfer(from, to, value);
        emit TransferByPartition(partition, operator, from, to, value, data, operatorData);
    }

    // Issue new tokens to a holder (no partition specified, will use default partition)
    function issue(address tokenHolder, uint256 value, bytes calldata data) external onlyMinter {
        require(_isIssuable, "Issuance not allowed");
        // Default to the first default partition or zero partition
        bytes32 partition = (_defaultPartitions.length > 0) ? _defaultPartitions[0] : bytes32(0);
        _issueByPartition(partition, tokenHolder, value, data);
    }

    // Issue new tokens into a specific partition
    function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) external onlyMinter {
        require(_isIssuable, "Issuance not allowed");
        _issueByPartition(partition, tokenHolder, value, data);
    }

    // Internal function to issue tokens of a given partition
    function _issueByPartition(bytes32 partition, address to, uint256 value, bytes memory data) internal {
        require(to != address(0), "Cannot issue to zero address");
        require(value % _granularity == 0, "Issued value not multiple of granularity");
        
        // No need for certificate check on issuance to self (minter is authorized)
        // but if certificate is required even for issuance, check if needed:
        // _checkCertificate(msg.sender, address(0), to, value, data);
        
        // Increase total supply and balances
        _totalSupply = _totalSupply.add(value);
        _totalSupplyByPartition[partition] = _totalSupplyByPartition[partition].add(value);
        _balanceOfByPartition[partition][to] = _balanceOfByPartition[partition][to].add(value);
        _balances[to] = _balances[to].add(value);
        _addPartitionForAddress(to, partition);
        _addPartitionToTotalList(partition);
        
        // Notify extension recipient hook if any - *Removed*
        // if (to.isContract()) {
        //     _callRecipientExtension(partition, msg.sender, address(0), to, value, data, "");
        // }

        emit Issued(msg.sender, to, value, data);
        emit Transfer(address(0), to, value);
        emit TransferByPartition(partition, msg.sender, address(0), to, value, data, "");
    }

    // Redeem (burn) tokens from caller
    function redeem(uint256 value, bytes calldata data) external {
        _redeemByPartition(_defaultPartitions.length > 0 ? _defaultPartitions[0] : bytes32(0), msg.sender, msg.sender, value, data, "");
    }

    // Redeem (burn) tokens from a tokenHolder (by operator)
    function redeemFrom(address tokenHolder, uint256 value, bytes calldata data) external {
        require(tokenHolder == msg.sender || isOperator(msg.sender, tokenHolder), "Not operator for holder");
        _redeemByPartition(_defaultPartitions.length > 0 ? _defaultPartitions[0] : bytes32(0), msg.sender, tokenHolder, value, data, "");
    }

    // Redeem tokens from a specific partition
    function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external {
        _redeemByPartition(partition, msg.sender, msg.sender, value, data, "");
    }

    // Operator redeem tokens from a specific partition
    function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData) external {
        require(isOperatorForPartition(partition, msg.sender, tokenHolder), "Not operator for partition");
        _redeemByPartition(partition, msg.sender, tokenHolder, value, data, operatorData);
    }

    // Internal function to redeem (burn) tokens from a partition
    function _redeemByPartition(bytes32 partition, address operator, address from, uint256 value, bytes memory data, bytes memory operatorData) internal {
        require(from != address(0), "Redeem from zero address");
        require(value % _granularity == 0, "Redeem value not multiple of granularity");
        require(_balanceOfByPartition[partition][from] >= value, "Insufficient balance");

        // Certificate check if required
        _checkCertificate(operator, from, address(0), value, data);

        // Update balances
        _balanceOfByPartition[partition][from] = _balanceOfByPartition[partition][from].sub(value);
        _totalSupplyByPartition[partition] = _totalSupplyByPartition[partition].sub(value);
        _balances[from] = _balances[from].sub(value);
        _totalSupply = _totalSupply.sub(value);
        _removePartitionForAddress(from, partition);

        // Extension hook for sender (burn) - *Removed*
        // _callSenderExtension(partition, operator, from, address(0), value, data, operatorData);

        emit Redeemed(operator, from, value, data);
        emit Transfer(from, address(0), value);
        emit TransferByPartition(partition, operator, from, address(0), value, data, operatorData);
    }

    // *** Operator management functions (ERC777-like) ***

    // Authorize an operator for all partitions
    function authorizeOperator(address operator) external {
        require(operator != msg.sender, "Cannot authorize self as operator");
        // Implement operator authorization (global) - e.g., set a flag mapping
        // For simplicity, we grant MinterRole to operator (if using MinterRole as proxy for operator rights)
        // In actual Codefi, they likely use separate mappings for operators.
        // Here we just emit the event.
        emit AuthorizedOperator(operator, msg.sender);
    }

    // Revoke an operator for all partitions
    function revokeOperator(address operator) external {
        require(operator != msg.sender, "Cannot revoke self");
        // Revoke operator rights (global)
        emit RevokedOperator(operator, msg.sender);
    }

    // Authorize an operator for a specific partition
    function authorizeOperatorByPartition(bytes32 partition, address operator) external {
        require(operator != msg.sender, "Cannot authorize self");
        // Implement partition-specific operator authorization (e.g., mapping partition->(holder->operator approved))
        emit AuthorizedOperatorByPartition(partition, operator, msg.sender);
    }

    // Revoke an operator for a specific partition
    function revokeOperatorByPartition(bytes32 partition, address operator) external {
        require(operator != msg.sender, "Cannot revoke self");
        // Implement partition-specific operator revocation
        emit RevokedOperatorByPartition(partition, operator, msg.sender);
    }

    // Check if an address is an authorized operator for another address (global)
    function isOperator(address operator, address tokenHolder) public view returns (bool) {
        if (operator == tokenHolder) {
            return true;
        }
        // Implement actual check (e.g., from a mapping of authorizedOperators[tokenHolder][operator])
        // For simplicity, no global operators unless set in controllers or roles.
        return false;
    }

    // Check if an address is an operator for a specific partition of a token holder
    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) public view returns (bool) {
        if (operator == tokenHolder) {
            return true;
        }
        // Implement actual check for partition-specific operator (if maintained in mapping)
        // For simplicity, treat same as global operator in this implementation.
        return isOperator(operator, tokenHolder);
    }

    // *** Migration function (upgrade mechanism) ***

    /**
     * @dev Migrate the contract to a new contract address. Only owner can call.
     * @param newContractAddress Address of the new contract to migrate to.
     * @param definitive If true, no further tokens can be issued or controlled from this contract after migration.
     */
    function migrate(address newContractAddress, bool definitive) external onlyOwner {
        require(newContractAddress != address(0), "New contract address is zero");

        // **All ERC1820 registry update logic removed**
        // ERC1820Client.setInterfaceImplementation(ERC1400_INTERFACE_NAME, newContractAddress);
        // ERC1820Client.setInterfaceImplementation(ERC20_INTERFACE_NAME, newContractAddress);
        // if (definitive) {
        //     ERC1820Client.setInterfaceImplementation(ERC1400_INTERFACE_NAME, address(0));
        //     ERC1820Client.setInterfaceImplementation(ERC20_INTERFACE_NAME, address(0));
        // }

        if (definitive) {
            // If definitive migration, prevent further issuance or controller operations on this old contract
            _isIssuable = false;
            _isControllable = false;
        }
        emit Migrated(newContractAddress, definitive);
    }

    // *** canTransfer functions (pre-flight check of transfer validity) ***

    /**
     * @dev Check if a transfer would be successful and return an appropriate reason and partition.
     * Implements ERC1400 canTransferByPartition and canTransfer (via default partition).
     */
    function canTransferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) external view returns (bytes1, bytes32, bytes32) {
        // If not enough balance in the specified partition:
        if (_balanceOfByPartition[partition][msg.sender] < value) {
            return (0x52, bytes32(0), partition); // 0x52 = insufficient balance
        }
        if (to == address(0)) {
            return (0x57, bytes32(0), partition); // 0x57 = invalid receiver (zero address)
        }
        if (value % _granularity != 0) {
            return (0x50, bytes32(0), partition); // 0x50 = transfer failure (granularity)
        }
        // Certificate check: if activated and certificate is required for msg.sender
        if (_certificateActivated && msg.sender != owner() && msg.sender != _certificateSigner) {
            // (In a full implementation, we would verify `data` contains a valid certificate from _certificateSigner)
            // Here, just ensure that if certificate is required, some data is provided:
            if (data.length == 0) {
                return (0x53, bytes32(0), partition); // 0x53 = invalid or missing certificate
            }
        }
        return (0x51, partition, partition); // 0x51 = transfer OK, partition remains same
    }

    // (Optionally, a canTransfer (no partition) function could be implemented to call canTransferByPartition on default partition.)

    // *** Internal helper functions for partition management and certificate checking ***

    // Remove tokens from a partition (update balance and holder's partition list)
    function _removeTokenFromPartition(address from, bytes32 partition, uint256 value) internal {
        _balanceOfByPartition[partition][from] = _balanceOfByPartition[partition][from].sub(value);
        if (_balanceOfByPartition[partition][from] == 0) {
            // if balance is zero, remove partition from holder's list
            _removePartitionForAddress(from, partition);
        }
    }

    // Add partition to holder's list if not already present
    function _addPartitionForAddress(address holder, bytes32 partition) internal {
        if (_balanceOfByPartition[partition][holder] > 0) {
            // if after transfer/issue the holder has this partition and it's not in list, add it
            if (_partitionsOf[holder].length == 0 || _partitionsOf[holder][_partitionsIndexOf[holder][partition]] != partition) {
                _partitionsOf[holder].push(partition);
                _partitionsIndexOf[holder][partition] = _partitionsOf[holder].length - 1;
            }
        }
    }

    // Remove partition from holder's list
    function _removePartitionForAddress(address holder, bytes32 partition) internal {
        uint256 index = _partitionsIndexOf[holder][partition];
        require(index != 0, "Partition not found");

        // 배열의 마지막 요소를 현재 위치로 이동
        uint256 lastIndex = _partitionsOf[holder].length - 1;
        if (index != lastIndex) {
            bytes32 lastPartition = _partitionsOf[holder][lastIndex];
            _partitionsOf[holder][index - 1] = lastPartition;
            _partitionsIndexOf[holder][lastPartition] = index;
        }

        // 마지막 요소 제거
        _partitionsOf[holder].pop();
        delete _partitionsIndexOf[holder][partition];
    }

    // Add partition to the global list of partitions if not present
    function _addPartitionToTotalList(bytes32 partition) internal {
        // Check if partition already in list (we can use total supply by partition as indicator)
        if (_totalSupplyByPartition[partition] == 0) {
            _totalPartitions.push(partition);
        }
    }

    // Certificate validation check (simplified)
    function _checkCertificate(address operator, address from, address to, uint256 value, bytes memory data) internal view {
        if (!_certificateActivated) {
            return;
        }
        // If certificate enforcement is on, and the transfer is not initiated by the certificate signer or contract owner,
        // then require that `data` contains a valid certificate signed by the certificate signer.
        if (operator != _certificateSigner && operator != owner()) {
            require(data.length > 0, "Certificate required");
            // In a full implementation, verify the signature in `data` against _certificateSigner and parameters.
        }
    }

    // *** ERC1820 extension hook functions removed ***
    /*
    function _callSenderExtension(bytes32 partition, address operator, address from, address to, uint256 value, bytes memory data, bytes memory operatorData) internal {
        // This function is intentionally left blank as ERC1820 logic is removed.
        // In the original implementation, this would lookup an implementer for ERC1400TokensSender and call `tokensToTransfer` on it.
    }

    function _callTokenExtension(bytes32 partition, address operator, address from, address to, uint256 value, bytes memory data, bytes memory operatorData) internal {
        // This function is intentionally left blank as ERC1820 logic is removed.
        // In the original implementation, this could call a validator contract for additional transfer controls.
    }

    function _callRecipientExtension(bytes32 partition, address operator, address from, address to, uint256 value, bytes memory data, bytes memory operatorData) internal {
        // This function is intentionally left blank as ERC1820 logic is removed.
        // In the original implementation, this would lookup an implementer for ERC1400TokensRecipient and call `tokensReceived` on it.
    }
    */
}
