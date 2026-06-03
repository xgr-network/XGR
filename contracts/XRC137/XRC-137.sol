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

    /// @dev Schema/version marker for explorer/MCP indexing.
    string public schemaVersion = "xrc137-rule@1";

    /// @dev Current canonical hash of ruleJson.
    bytes32 public ruleHash;

    /// @dev Monotonic rule version. Starts at 1 after deployment.
    uint256 public ruleVersion;

    /// @dev Encryption metadata; rid == 0x0 means "not encrypted"
    struct EncInfo {
        bytes32 rid;    // sha256(nonce||ciphertext)
        string suite;   // e.g., "AES-256-GCM-1"
        bytes encDEK;   // Der EncDEK als byte[]-Array
    }

    EncInfo public encrypted;

    // --- Existing events ---
    event RuleUpdated(string newRule);
    event EncryptedSet(bytes32 rid, string suite);
    event EncryptedCleared();

    // --- Explorer / MCP index events ---
    event XRC137Deployed(
        address indexed ruleAddress,
        address indexed owner,
        bytes32 indexed ruleHash,
        uint256 version,
        string nameXRC,
        string schemaVersion,
        bool encryptedState
    );

    event XRC137Updated(
        address indexed ruleAddress,
        address indexed owner,
        bytes32 indexed ruleHash,
        uint256 version,
        bool encryptedState
    );

    constructor(string memory _json) {
        owner = msg.sender;
        ruleJson = _json;
        // encrypted.rid remains zero => plaintext by default

        _indexRule();

        emit XRC137Deployed(
            address(this),
            msg.sender,
            ruleHash,
            ruleVersion,
            nameXRC,
            schemaVersion,
            false
        );
    }

    // --- Executor management (owner only) ---
    function addExecutor(address exec) external onlyOwner {
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

    function getRuleHash() external view returns (bytes32) {
        return ruleHash;
    }

    function getRuleVersion() external view returns (uint256) {
        return ruleVersion;
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
            // Do NOT touch 'encrypted' here (metadata already set).
        } else {
            // Plaintext -> encryption must be cleared to keep invariants.
            if (encrypted.rid != bytes32(0)) {
                delete encrypted;
                emit EncryptedCleared();
            }
        }

        _indexRule();

        emit XRC137Updated(
            address(this),
            msg.sender,
            ruleHash,
            ruleVersion,
            encrypted.rid != bytes32(0)
        );
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

            _indexRule();

            emit XRC137Updated(
                address(this),
                msg.sender,
                ruleHash,
                ruleVersion,
                false
            );

            return;
        }

        require(_startsWithXGR1(_jsonOrBlob), "expected XGR1 blob");

        ruleJson = _jsonOrBlob;
        encrypted = EncInfo({
            rid: rid,
            suite: suite,
            encDEK: encDEK
        });

        emit RuleUpdated(_jsonOrBlob);
        emit EncryptedSet(rid, suite);

        _indexRule();

        emit XRC137Updated(
            address(this),
            msg.sender,
            ruleHash,
            ruleVersion,
            true
        );
    }

    // --- Ownership utils ---
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero addr");
        owner = newOwner;
    }

    // --- Internals ---
    function _indexRule() internal {
        ruleHash = keccak256(bytes(ruleJson));
        ruleVersion += 1;
    }

    function _startsWithXGR1(string memory s) internal pure returns (bool) {
        bytes memory b = bytes(s);

        if (b.length < 5) {
            return false;
        }

        // "XGR1." in ASCII: 0x58 0x47 0x52 0x31 0x2e
        return (
            b[0] == 0x58 &&
            b[1] == 0x47 &&
            b[2] == 0x52 &&
            b[3] == 0x31 &&
            b[4] == 0x2e
        );
    }
}
