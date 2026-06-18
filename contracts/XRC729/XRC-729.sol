// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title XRC-729 OSTC Registry (JSON-only)
/// @notice Stores orchestrations (OSTC) as JSON under a string ID.
///         The RPC/Engine reads the JSON off-chain and interprets it.
/// @dev Includes optional executor allowlist for delegated xDaLa authorization.
contract XRC729 {
    // --- Ownership ---
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "XRC729: not owner");
        _;
    }

    // --- Registry name ---
    string public nameXRC = "XGR_XRC729";

    /// @dev Schema/version marker for explorer/MCP indexing.
    string public schemaVersion = "xrc729-ostc@1";

    // --- Executors (optional ACL; does NOT affect OSTC mutability) ---
    address[] private executorList;
    mapping(address => uint256) private executorIndex; // 1-based; 0 == not present

    event ExecutorAdded(address indexed executor);
    event ExecutorRemoved(address indexed executor);

    // --- OSTC storage ---
    // ID -> JSON
    mapping(string => string) private ostcJSON;

    // ID -> content hash/version/update time
    mapping(string => bytes32) private ostcHash;
    mapping(string => uint256) private ostcVersion;
    mapping(string => uint64) private ostcUpdatedAt;

    // Listing of all IDs
    string[] private ostcIds;

    // 1-based index mapping for O(1) swap-delete; 0 == not present
    mapping(string => uint256) private ostcIndex;

    // --- Existing events ---
    event OSTCSet(string indexed id);
    event OSTCDeleted(string indexed id);

    // --- Explorer / MCP index events ---
    event XRC729Deployed(
        address indexed xrc729Address,
        address indexed owner,
        bytes32 indexed nameHash,
        string nameXRC,
        string schemaVersion
    );

    event OSTCUpdated(
        address indexed xrc729Address,
        address indexed owner,
        bytes32 indexed ostcIdHash,
        bytes32 ostcHash,
        string id,
        uint256 version,
        uint64 updatedAt
    );

    event OSTCDeletedIndexed(
        address indexed xrc729Address,
        address indexed owner,
        bytes32 indexed ostcIdHash,
        bytes32 previousOstcHash,
        string id,
        uint256 previousVersion
    );

    // --- Constructor ---
    constructor(
        string[] memory initialOstcIds,
        string[] memory initialOstcJsons,
        address[] memory initialExecutors
    ) {
        require(
            initialOstcIds.length == initialOstcJsons.length,
            "XRC729: OSTC array length mismatch"
        );

        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);

        emit XRC729Deployed(
            address(this),
            msg.sender,
            keccak256(bytes(nameXRC)),
            nameXRC,
            schemaVersion
        );
        for (uint256 i = 0; i < initialOstcIds.length; i++) {
            _setOSTC(initialOstcIds[i], initialOstcJsons[i]);
        }

        for (uint256 i = 0; i < initialExecutors.length; i++) {
            _addExecutorInternal(initialExecutors[i]);
        }
    }

    // --- Ownership management ---

    /// @notice Transfers ownership to a new address.
    /// @param newOwner The address of the new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "XRC729: zero address");

        // If new owner was an executor, remove them (owner is implicitly authorized)
        uint256 idx1b = executorIndex[newOwner];
        if (idx1b != 0) {
            _removeExecutorInternal(newOwner);
        }

        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // --- Executor management (owner only) ---

    /// @notice Adds an executor to the allowlist.
    /// @param exec The address to add as executor.
    function addExecutor(address exec) external onlyOwner {
        _addExecutorInternal(exec);
    }

    /// @dev Internal executor add logic used by constructor and addExecutor.
    ///      Emits the same ExecutorAdded event as the external addExecutor path.
    function _addExecutorInternal(address exec) internal {
        require(exec != address(0), "XRC729: zero executor");
        require(exec != owner, "XRC729: owner cannot be executor");

        if (executorIndex[exec] != 0) {
            return; // Already present
        }

        executorList.push(exec);
        executorIndex[exec] = executorList.length; // 1-based

        emit ExecutorAdded(exec);
    }

    /// @notice Removes an executor from the allowlist.
    /// @param exec The address to remove.
    function removeExecutor(address exec) external onlyOwner {
        _removeExecutorInternal(exec);
    }

    /// @dev Internal executor removal with swap-delete pattern.
    function _removeExecutorInternal(address exec) internal {
        uint256 idx1b = executorIndex[exec];

        if (idx1b == 0) {
            return; // Not present
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

    /// @notice Returns the list of all executors.
    /// @return Array of executor addresses.
    function getExecutorList() external view returns (address[] memory) {
        return executorList;
    }

    function isExecutor(address a) external view returns (bool) {
        return executorIndex[a] != 0;
    }

    // --- OSTC management ---

    /// @dev Internal function to set an OSTC.
    function _setOSTC(string memory id, string memory json) internal {
        if (ostcIndex[id] == 0) {
            ostcIds.push(id);
            ostcIndex[id] = ostcIds.length; // 1-based
        }

        ostcJSON[id] = json;
        ostcHash[id] = keccak256(bytes(json));
        ostcVersion[id] += 1;
        ostcUpdatedAt[id] = uint64(block.timestamp);

        emit OSTCSet(id);

        emit OSTCUpdated(
            address(this),
            msg.sender,
            keccak256(bytes(id)),
            ostcHash[id],
            id,
            ostcVersion[id],
            ostcUpdatedAt[id]
        );
    }

    /// @notice Creates or updates an OSTC under the given ID.
    /// @param id The orchestration identifier.
    /// @param json The OSTC JSON string.
    function setOSTC(string calldata id, string calldata json) external onlyOwner {
        _setOSTC(id, json);
    }

    /// @notice Deletes an OSTC by ID (uses swap-delete for the ID list).
    /// @param id The orchestration identifier to delete.
    function deleteOSTC(string calldata id) external onlyOwner {
        uint256 idx1b = ostcIndex[id];
        require(idx1b != 0, "XRC729: not found");

        bytes32 previousHash = ostcHash[id];
        uint256 previousVersion = ostcVersion[id];

        uint256 idx = idx1b - 1;
        uint256 last = ostcIds.length - 1;

        if (idx != last) {
            string memory moved = ostcIds[last];
            ostcIds[idx] = moved;
            ostcIndex[moved] = idx + 1;
        }

        ostcIds.pop();

        delete ostcIndex[id];
        delete ostcJSON[id];
        delete ostcHash[id];
        delete ostcVersion[id];
        delete ostcUpdatedAt[id];

        emit OSTCDeleted(id);

        emit OSTCDeletedIndexed(
            address(this),
            msg.sender,
            keccak256(bytes(id)),
            previousHash,
            id,
            previousVersion
        );
    }

    // --- Read functions ---

    /// @notice Returns all registered OSTC IDs.
    /// @return Array of all OSTC identifiers.
    function getAllOSTC() external view returns (string[] memory) {
        return ostcIds;
    }

    /// @notice Returns the JSON for an OSTC by ID.
    /// @param id The orchestration identifier.
    /// @return The OSTC JSON string.
    function getOSTC(string calldata id) external view returns (string memory) {
        require(ostcIndex[id] != 0, "XRC729: not found");
        return ostcJSON[id];
    }

    /// @notice Returns index metadata for an OSTC by ID.
    function getOSTCMeta(
        string calldata id
    )
        external
        view
        returns (
            bytes32 hash,
            uint256 version,
            uint64 updatedAt
        )
    {
        require(ostcIndex[id] != 0, "XRC729: not found");
        return (ostcHash[id], ostcVersion[id], ostcUpdatedAt[id]);
    }

    /// @notice Checks if an OSTC exists.
    /// @param id The orchestration identifier.
    /// @return True if the OSTC exists.
    function hasOSTC(string calldata id) external view returns (bool) {
        return ostcIndex[id] != 0;
    }

    /// @notice Returns the registry name.
    /// @return The nameXRC string.
    function getNameXRC() public view returns (string memory) {
        return nameXRC;
    }
}
