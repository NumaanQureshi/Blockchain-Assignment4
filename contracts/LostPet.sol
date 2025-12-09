// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LostPet
 * @notice Simple contract for lost pet bounties
 */
contract LostPet {
    // Basic state variables
    uint256 public nextCaseId;
    mapping(uint256 => PetCase) public cases;

    mapping(uint256 => address[]) public caseFinders;
    mapping(uint256 => mapping(address => bool)) public isFinderForCase;
    mapping(uint256 => mapping(address => string)) public finderEvidence;
    
    // Constants for gas optimization
    uint256 public constant DEFAULT_EXPIRY_DAYS = 90 days;
    uint256 public constant MIN_BOUNTY = 0.001 ether;
    
    // Case status enum
    enum CaseStatus { Active, Resolved, Cancelled, Expired }

    // Simple struct - only essential fields
    struct PetCase {
        address owner;
        string petName;
        uint256 bounty;
        CaseStatus status;
        uint256 createdAt;
        uint256 expiresAt;
    }
    
    // Only essential events
    event CaseCreated(uint256 indexed caseId, address indexed owner, string petName, uint256 bounty, uint256 expiresAt);
    event FinderSubmitted(uint256 indexed caseId, address indexed finder, string evidence);
    event CaseResolved(uint256 indexed caseId, address indexed finder, uint256 bountyAmount);
    event IncreaseBounty(uint256 indexed caseId, uint256 additionalAmount, uint256 newTotal);
    event CaseCancelled(uint256 indexed caseId, address indexed owner, uint256 refundAmount);
    event CaseExpired(uint256 indexed caseId, address indexed owner, uint256 refundAmount);
    
    // =============================================
    // OWNER-ONLY FUNCTIONS
    // =============================================
    
    /**
     * @notice Create a lost pet case with bounty
     */
    function createCase(string calldata petName) external payable returns (uint256 caseId) {
        require(msg.value >= MIN_BOUNTY, "Bounty must be at least 0.001 ETH");
        require(bytes(petName).length > 0, "Pet name cannot be empty");
        
        caseId = nextCaseId;
        nextCaseId++;
        
        uint256 expiresAt = block.timestamp + DEFAULT_EXPIRY_DAYS;
        
        cases[caseId] = PetCase({
            owner: msg.sender,
            petName: petName,
            bounty: msg.value,
            status: CaseStatus.Active,
            createdAt: block.timestamp,
            expiresAt: expiresAt
        });
        
        emit CaseCreated(caseId, msg.sender, petName, msg.value, expiresAt);
        return caseId;
    }
    
    /**
     * @notice Increase bounty for an existing case
     * @dev Only case owner can call this function
     */
    function increaseBounty(uint256 caseId) external payable {
        require(msg.sender == cases[caseId].owner, "Only case owner can increase bounty");
        require(cases[caseId].status == CaseStatus.Active, "Case not active");
        require(block.timestamp < cases[caseId].expiresAt, "Case expired");
        require(msg.value > 0, "Must send ETH");
        
        cases[caseId].bounty += msg.value;
        
        emit IncreaseBounty(caseId, msg.value, cases[caseId].bounty);
    }
    
    /**
     * @notice Resolve case and pay bounty to a finder
     * @dev Only case owner can call this function
     */
    function resolveCase(uint256 caseId, uint256 finderIndex) external {
        require(msg.sender == cases[caseId].owner, "Only case owner can resolve");
        require(cases[caseId].status == CaseStatus.Active, "Case not active");
        require(block.timestamp < cases[caseId].expiresAt, "Case expired");
        require(finderIndex < caseFinders[caseId].length, "Invalid finder index");
        
        // Wallet/Escrow check
        require(address(this).balance >= cases[caseId].bounty, "Insufficient contract balance");
        
        address finder = caseFinders[caseId][finderIndex];
        uint256 bounty = cases[caseId].bounty;
        
        // Update state before sending money
        cases[caseId].status = CaseStatus.Resolved;
        cases[caseId].bounty = 0;
        
        // Send bounty to finder
        (bool success, ) = payable(finder).call{value: bounty}("");
        require(success, "Transfer failed");
        
        emit CaseResolved(caseId, finder, bounty);
    }
    
    /**
     * @notice Cancel case and get refund
     * @dev Only case owner can call this function
     */
    function cancelCase(uint256 caseId) external {
        require(msg.sender == cases[caseId].owner, "Only owner can cancel");
        require(caseFinders[caseId].length == 0, "Cannot cancel - finders already submitted");
        require(cases[caseId].status == CaseStatus.Active, "Case not active");
        require(block.timestamp < cases[caseId].expiresAt, "Case expired");
        
        // Time restriction
        require(block.timestamp >= cases[caseId].createdAt + 7 days, "Cannot cancel before 7 days");
        
        uint256 refundAmount = cases[caseId].bounty;
        cases[caseId].status = CaseStatus.Cancelled;
        cases[caseId].bounty = 0;
        
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund failed");
        
        emit CaseCancelled(caseId, msg.sender, refundAmount);
    }
    
    // =============================================
    // PUBLIC FUNCTIONS
    // =============================================
    
    /**
     * @notice Submit yourself as a finder for a case
     */
    function submitAsFinder(uint256 caseId, string calldata evidence) external {
        require(caseId < nextCaseId, "Case does not exist");
        require(cases[caseId].status == CaseStatus.Active, "Case not active");
        require(block.timestamp < cases[caseId].expiresAt, "Case expired");
        require(!isFinderForCase[caseId][msg.sender], "Already submitted as finder");
        require(bytes(evidence).length > 0, "Evidence cannot be empty");
        
        caseFinders[caseId].push(msg.sender);
        isFinderForCase[caseId][msg.sender] = true;
        finderEvidence[caseId][msg.sender] = evidence;
        
        emit FinderSubmitted(caseId, msg.sender, evidence);
    }
    
    // =============================================
    // TIME LIMIT FUNCTIONS
    // =============================================
    
    /**
     * @notice Check and process expired cases
     */
    function checkAndProcessExpiry(uint256 caseId) external returns (bool processed) {
        require(caseId < nextCaseId, "Case does not exist");
        
        if (cases[caseId].status == CaseStatus.Active && 
            block.timestamp >= cases[caseId].expiresAt && 
            cases[caseId].bounty > 0) {
            
            uint256 refundAmount = cases[caseId].bounty;
            cases[caseId].status = CaseStatus.Expired;
            cases[caseId].bounty = 0;
            
            (bool success, ) = payable(cases[caseId].owner).call{value: refundAmount}("");
            require(success, "Refund failed");
            
            emit CaseExpired(caseId, cases[caseId].owner, refundAmount);
            return true;
        }
        return false;
    }
    
    // =============================================
    // VIEW FUNCTIONS
    // =============================================
    
    /**
     * @notice Get basic case info (low gas)
     */
    function getCaseBasic(uint256 caseId) external view returns (
        address owner,
        uint256 bounty,
        bool isResolved
    ) {
        require(caseId < nextCaseId, "Case does not exist");
        PetCase storage pc = cases[caseId];
        return (pc.owner, pc.bounty, pc.status == CaseStatus.Resolved);
    }
    
    /**
     * @notice Get total number of cases
     */
    function getTotalCases() external view returns (uint256) {
        return nextCaseId;
    }
    
    /**
     * @notice Check if case is expired
     */
    function isCaseExpired(uint256 caseId) external view returns (bool) {
        require(caseId < nextCaseId, "Case does not exist");
        return block.timestamp >= cases[caseId].expiresAt;
    }
    
    /**
     * @notice Get finders for a case
     */
    function getFinders(uint256 caseId) external view returns (address[] memory) {
        require(caseId < nextCaseId, "Case does not exist");
        return caseFinders[caseId];
    }
    
    /**
     * @notice Check if an address is a finder for a specific case
     */
    function isFinder(uint256 caseId, address finder) external view returns (bool) {
        require(caseId < nextCaseId, "Case does not exist");
        return isFinderForCase[caseId][finder];
    }
    
    /**
     * @notice Get full case details (higher gas)
     * @dev preserves previous return types for compatibility:
     * returns isResolved and isCancelled booleans computed from enum
     */
    function getCaseFull(uint256 caseId) external view returns (
        address owner,
        string memory petName,
        uint256 bounty,
        bool isResolved,
        bool isCancelled,
        uint256 createdAt,
        uint256 expiresAt,
        uint256 finderCount
    ) {
        require(caseId < nextCaseId, "Case does not exist");
        
        PetCase storage petCase = cases[caseId];
        bool resolved = petCase.status == CaseStatus.Resolved;
        bool cancelled = (petCase.status == CaseStatus.Cancelled || petCase.status == CaseStatus.Expired);
        return (
            petCase.owner,
            petCase.petName,
            petCase.bounty,
            resolved,
            cancelled,
            petCase.createdAt,
            petCase.expiresAt,
            caseFinders[caseId].length
        );
    }
    
    /**
     * @notice Get paginated finders (gas efficient for large lists)
     */
    function getFindersPaginated(uint256 caseId, uint256 startIndex, uint256 count) 
        external 
        view 
        returns (address[] memory finders) 
    {
        require(caseId < nextCaseId, "Case does not exist");
        require(startIndex < caseFinders[caseId].length, "Invalid start index");
        
        uint256 endIndex = startIndex + count;
        if (endIndex > caseFinders[caseId].length) {
            endIndex = caseFinders[caseId].length;
        }
        
        finders = new address[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            finders[i - startIndex] = caseFinders[caseId][i];
        }
        return finders;
    }

    /**
     * @notice View the evidence submitted by a specific finder
     */
    function getFinderEvidence(uint256 caseId, address finder)
        external
        view
        returns (string memory evidence)
    {
        require(caseId < nextCaseId, "Case does not exist");
        return finderEvidence[caseId][finder];
    }
    
    /**
     * @notice Get total ETH held in escrow
     * @return total Total amount of ETH held for all active bounties
     */
    function getTotalEscrow() external view returns (uint256 total) {
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (!cases[i].isResolved && !cases[i].isCancelled) {
                total += cases[i].bounty;
            }
        }
        return total;
    }
    
    /**
     * @notice Get escrow for specific case
     */
    function getCaseEscrow(uint256 caseId) external view returns (uint256) {
        require(caseId < nextCaseId, "Case does not exist");
        
        if (cases[caseId].isResolved || cases[caseId].isCancelled) {
            return 0;
        }
        return cases[caseId].bounty;
    }
    
    /**
     * @notice Verify case has sufficient funds
     */
    function isCaseFunded(uint256 caseId) external view returns (bool) {
        require(caseId < nextCaseId, "Case does not exist");
        return address(this).balance >= cases[caseId].bounty;
    }
    
    /**
     * @notice Batch check multiple cases for expiry
     */
    function batchCheckExpiry(uint256[] calldata caseIds) external returns (uint256 processedCount) {
        for (uint256 i = 0; i < caseIds.length; i++) {
            if (checkAndProcessExpiry(caseIds[i])) {
                processedCount++;
            }
        }
        return processedCount;
    }
    
    /**
     * @notice Get active cases (unresolved, uncancelled, not expired)
     * TODO: NOT STARTED
     * MISSING: Implement this function to return array of active case IDs
     * MISSING: Should filter cases based on isResolved, isCancelled, and expiresAt
     */
    function getActiveCases() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // First pass: count active cases
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (!cases[i].isResolved && !cases[i].isCancelled && block.timestamp < cases[i].expiresAt) {
                activeCount++;
            }
        }
        
        // Second pass: populate array
        uint256[] memory activeCases = new uint256[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (!cases[i].isResolved && !cases[i].isCancelled && block.timestamp < cases[i].expiresAt) {
                activeCases[currentIndex] = i;
                currentIndex++;
            }
        }
        
        return activeCases;
    }
    
    /**
     * @notice Get cases created by a specific owner
     * TODO: NOT STARTED
     * MISSING: Implement this function and add necessary data structures
     * MISSING: Need to add mapping(address => uint256[]) ownerCases
     * MISSING: Update mapping in createCase function
     */
    function getCasesByOwner(address owner) external view returns (uint256[] memory) {
        revert("Not implemented yet");
    }
}