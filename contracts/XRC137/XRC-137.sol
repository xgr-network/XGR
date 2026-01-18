// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title XRC-137 (with Encryption Header)
/// @notice Stores the rule JSON (either plaintext or an XGR1-blob) and encryption metadata.
contract XRC137 {
    // --- Minimal ownership (no OZ) ---
    address public owner;

    // --- Executors (optional ACL; does NOT affect rule mutability) ---
   address[] private executorList;
    mapping(address => uint256) private executorIndex; // 1-based; 0 == not present

    event ExecutorAdded(address indexed executor);
    event ExecutorRemoved(address indexed executor);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // --- Public state ---
    /// @dev Plaintext JSON or an encrypted blob like "XGR1.AESGCM...."
    string public ruleJson;

    /// @dev Human-readable identifier
    string public nameXRC = "XGR_XRC137";

    /// @dev Encryption metadata; rid == 0x0 means "not encrypted"
    struct EncInfo {
        bytes32 rid;   // sha256(nonce||ciphertext)
        string  suite; // e.g., "AES-256-GCM-1"
        bytes   encDEK; // Der EncDEK als byte[]-Array
    }
    EncInfo public encrypted;

    // --- Events ---
    event RuleUpdated(string newRule);
    event EncryptedSet(bytes32 rid, string suite);
    event EncryptedCleared();

    constructor(string memory _json) {
        owner = msg.sender;
        ruleJson = _json;
        // encrypted.rid remains zero => plaintext by default
   }

    // --- Executor management (owner only) ---
    function addExecutor(address exec) external onlyOwner {
        require(exec != address(0), "zero addr");
        require(exec != owner, "owner cannot be executor");
        if (executorIndex[exec] != 0) {
            return;
        }
        executorList.push(exec);
        executorIndex[exec] = executorList.length; // 1-based
        emit ExecutorAdded(exec);
    }

    function removeExecutor(address exec) external onlyOwner {
        uint256 idx1b = executorIndex[exec];
        if (idx1b == 0) {
            return;
        }

        uint256 idx = idx1b - 1;
        uint256 last = executorList.length - 1;
        if (idx != last) {
            address moved = executorList[last];
            executorList[idx] = moved;
            executorIndex[moved] = idx + 1;
        }
       executorList.pop();
        delete executorIndex[exec];

        emit ExecutorRemoved(exec);
    }

    function getExecutorList() external view returns (address[] memory) {
        return executorList;
    }
	
	function isExecutor(address a) external view returns (bool) {
		return executorIndex[a] != 0;
	}
	

    /// @notice Fast ACL check used by engine preflight/wakeup.
    function isExecutor(address exec) external view returns (bool) {
        return executorIndex[exec] != 0;
    }

    // --- Views ---
    function getRule() external view returns (string memory) {
        return ruleJson;
    }

    function getNameXRC() external view returns (string memory) {
        return nameXRC;
    }

    /// @notice Returns true if `ruleJson` is encrypted (RID set).
    function isEncrypted() external view returns (bool) {
        return encrypted.rid != bytes32(0);
    }

    // --- Mutations (owner only) ---

    /// @notice Updates ONLY the rule JSON/blob.
    /// @dev Plaintext -> Auto-clear encryption.
    ///      XGR1.* -> require metadata to be provided via setEncrypted/setRuleAndEncrypted.
    function updateRule(string memory _jsonOrBlob) external onlyOwner {
        ruleJson = _jsonOrBlob;
        emit RuleUpdated(_jsonOrBlob);

        if (_startsWithXGR1(_jsonOrBlob)) {
            // If caller wants to set an encrypted blob, the metadata must be set explicitly
            // to avoid inconsistent states.
            require(
                encrypted.rid != bytes32(0),
                "encrypted meta required: call setRuleAndEncrypted or setEncrypted first"
            );
            // Do NOT touch 'encrypted' here (metadata already set or will be set right after).
        } else {
            // Plaintext -> encryption must be cleared to keep invariants.
            if (encrypted.rid != bytes32(0)) {
                delete encrypted;
                emit EncryptedCleared();
            }
        }
    }

    /// @notice Convenience: update rule + encryption metadata in a single transaction.
    /// @dev Typically used with an XGR1-blob as `_jsonOrBlob`.
    function setRuleAndEncrypted(
        string calldata _jsonOrBlob,
        bytes32 rid,
        string calldata suite,
        bytes calldata encDEK
    ) external onlyOwner {
        if (rid == bytes32(0)) {
            // Treat as plaintext write + clear
            ruleJson = _jsonOrBlob;
            emit RuleUpdated(_jsonOrBlob);
            if (encrypted.rid != bytes32(0)) {
                delete encrypted;
                emit EncryptedCleared();
            }
            return;
        }

        require(_startsWithXGR1(_jsonOrBlob), "expected XGR1 blob");
        ruleJson = _jsonOrBlob;
        encrypted = EncInfo({rid: rid, suite: suite, encDEK: encDEK});
        emit RuleUpdated(_jsonOrBlob);
        emit EncryptedSet(rid, suite);
    }

    // --- Ownership utils ---
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero addr");
        owner = newOwner;
    }

    // --- Internals ---
    function _startsWithXGR1(string memory s) internal pure returns (bool) {
        bytes memory b = bytes(s);
        if (b.length < 5) return false;
        // "XGR1." in ASCII: 0x58 0x47 0x52 0x31 0x2e
        return b[0] == 0x58 && b[1] == 0x47 && b[2] == 0x52 && b[3] == 0x31 && b[4] == 0x2e;
    }
}
