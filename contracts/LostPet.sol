// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/LostPetInterface.sol";

/**
 * @title LostPet
 * @notice Simple contract for lost pet bounties
 */
contract LostPet is LostPetInterface{
    // Basic state variables
    uint256 public nextCaseId;

    // Case status enum
    enum CaseStatus { Active, Resolved, Cancelled, Expired }

    // Simple struct - only essential fields
    struct CaseData {
        address owner;
        string petName;
        uint256 bounty;
        CaseStatus status;
        uint256 createdAt;
        uint256 expiresAt;
    }
    
    mapping(uint256 => CaseData) private cases;
    mapping(address => uint256[]) private ownerCases;

    mapping(uint256 => address[]) private caseFinders;
    mapping(uint256 => mapping(address => bool)) private isFinderForCase;
    mapping(uint256 => mapping(address => string)) private finderEvidence;
    
    // Constants for gas optimization
    uint256 public constant DEFAULT_EXPIRY_DAYS = 90 days;
    uint256 public constant MIN_BOUNTY = 0.001 ether;
    uint256 public constant MIN_RESOLVE_TIME = 1 days;
    
    
    // =============================================
    // OWNER-ONLY FUNCTIONS
    // =============================================
    
    /**
     * @notice Create a lost pet case with bounty
     */
    function createCase(string calldata petName) external payable override returns (uint256 caseId) {
        require(msg.value >= MIN_BOUNTY, "Bounty must be at least 0.001 ETH");
        require(bytes(petName).length > 0, "Pet name cannot be empty");
        
        caseId = nextCaseId;
        nextCaseId++;
        
        uint256 expiresAt = block.timestamp + DEFAULT_EXPIRY_DAYS;
        
        cases[caseId] = CaseData({
            owner: msg.sender,
            petName: petName,
            bounty: msg.value,
            status: CaseStatus.Active,
            createdAt: block.timestamp,
            expiresAt: expiresAt
        });
        
        ownerCases[msg.sender].push(caseId);
        
        emit CaseCreated(caseId, msg.sender, petName, msg.value, expiresAt);
    }
    
    /**
     * @notice Increase bounty for an existing case
     * @dev Only case owner can call this function
     */
    function increaseBounty(uint256 caseId) external payable override{
        CaseData storage c = cases[caseId];

        require(msg.sender == c.owner, "Only case owner can increase bounty");
        require(c.status == CaseStatus.Active, "Case not active");
        require(block.timestamp < c.expiresAt, "Case expired");
        require(msg.value > 0, "Must send ETH");
        
        c.bounty += msg.value;
        
        emit IncreaseBounty(caseId, msg.value, c.bounty);
    }
    
    /**
     * @notice Resolve case and pay bounty to a finder
     * @dev Only case owner can call this function
     * @dev Case must exist for minimum time before resolution
     */
    function resolveCase(uint256 caseId, uint256 finderIndex) external override{
        CaseData storage c = cases[caseId];

        require(msg.sender == c.owner, "Only case owner can resolve");
        require(c.status == CaseStatus.Active, "Case not active");
        require(block.timestamp < c.expiresAt, "Case expired");
        require(block.timestamp >= c.createdAt + MIN_RESOLVE_TIME, "Case too new to resolve");
        require(finderIndex < caseFinders[caseId].length, "Invalid finder index");
        
        // Wallet/Escrow check
        require(address(this).balance >= c.bounty, "Insufficient contract balance");
        
        address finder = caseFinders[caseId][finderIndex];
        uint256 bounty = c.bounty;
        
        // Update state before sending money
        c.status = CaseStatus.Resolved;
        c.bounty = 0;
        
        // Send bounty to finder
        (bool success, ) = payable(finder).call{value: bounty}("");
        require(success, "Transfer failed");
        
        emit CaseResolved(caseId, finder, bounty);
    }
    
    /**
     * @notice Cancel case and get refund
     * @dev Only case owner can call this function
     */
    function cancelCase(uint256 caseId) external override{
        CaseData storage c = cases[caseId];

        require(msg.sender == c.owner, "Only owner can cancel");
        require(caseFinders[caseId].length == 0, "Cannot cancel - finders already submitted");
        require(c.status == CaseStatus.Active, "Case not active");
        require(block.timestamp < c.expiresAt, "Case expired");
        
        // Time restriction
        require(block.timestamp >= c.createdAt + 7 days, "Cannot cancel before 7 days");
        
        uint256 refundAmount = c.bounty;
        c.status = CaseStatus.Cancelled;
        c.bounty = 0;
        
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
    function submitAsFinder(uint256 caseId, string calldata evidence) external override{
        require(caseId < nextCaseId, "Case does not exist");
        CaseData storage c = cases[caseId];

        require(c.status == CaseStatus.Active, "Case not active");
        require(block.timestamp < c.expiresAt, "Case expired");
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
    function checkAndProcessExpiry(uint256 caseId) public override returns (bool processed) {
        require(caseId < nextCaseId, "Case does not exist");
        CaseData storage c = cases[caseId];
        
        if (c.status == CaseStatus.Active && 
            block.timestamp >= c.expiresAt && 
            c.bounty > 0) {
            
            uint256 refundAmount = c.bounty;
            c.status = CaseStatus.Expired;
            c.bounty = 0;
            
            (bool success, ) = payable(c.owner).call{value: refundAmount}("");
            require(success, "Refund failed");
            
            emit CaseExpired(caseId, c.owner, refundAmount);
            return true;
        }
        return false;
    }

    /**
     * @notice Batch check multiple cases for expiry
     */
    function batchCheckExpiry(uint256[] calldata caseIds) external override returns (uint256 processedCount) {
        for (uint256 i = 0; i < caseIds.length; i++) {
            if (checkAndProcessExpiry(caseIds[i])) {
                processedCount++;
            }
        }
    }
    
    // =============================================
    // VIEW FUNCTIONS
    // =============================================
    
    /**
     * @notice Get basic case info (low gas)
     */
    function getCaseBasic(uint256 caseId) external view override returns (address owner, uint256 bounty, bool isResolved) {
        require(caseId < nextCaseId, "Case does not exist");
        CaseData storage c = cases[caseId];

        return (c.owner, c.bounty, c.status == CaseStatus.Resolved);
    }
    
    /**
     * @notice Get total number of cases
     */
    function getTotalCases() external view override returns (uint256) {
        return nextCaseId;
    }
    
    /**
     * @notice Check if case is expired
     */
    function isCaseExpired(uint256 caseId) external view override returns (bool) {
        require(caseId < nextCaseId, "Case does not exist");
        return block.timestamp >= cases[caseId].expiresAt;
    }
    
    /**
     * @notice Get finders for a case
     */
    function getFinders(uint256 caseId) external view override returns (address[] memory) {
        require(caseId < nextCaseId, "Case does not exist");
        return caseFinders[caseId];
    }

    /**
     * @notice Get number of finders for a case
     */
    function getFinderCount(uint256 caseId) external view override returns (uint256) {
        require(caseId < nextCaseId, "Case does not exist");
        return caseFinders[caseId].length;
    }
    
    /**
     * @notice Check if an address is a finder for a specific case
     */
    function isFinder(uint256 caseId, address finder) external view override returns (bool) {
        require(caseId < nextCaseId, "Case does not exist");
        return isFinderForCase[caseId][finder];
    }
    
    /**
     * @notice Get paginated finders (gas efficient for large lists)
     * @dev Returns empty array instead of reverting when startIndex is out-of-range.
     */
    function getFindersPaginated(uint256 caseId, uint256 startIndex, uint256 count) external view override returns (address[] memory finders){
        require(caseId < nextCaseId, "Case does not exist");

        uint256 length = caseFinders[caseId].length;
        if (count == 0 || startIndex >= length) {
            return new address[](0);
        }

        uint256 endIndex = startIndex + count;
        if (endIndex > length) {
            endIndex = length;
        }

        finders = new address[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            finders[i - startIndex] = caseFinders[caseId][i];
        }
    }

    /**
     * @notice View the evidence submitted by a specific finder
     */
    function getFinderEvidence(uint256 caseId, address finder) external view override returns (string memory){
        require(caseId < nextCaseId, "Case does not exist");
        return finderEvidence[caseId][finder];
    }

    /**
     * @notice Get full case details (higher gas)
     * @dev Returns the case status as enum value (0=Active, 1=Resolved, 2=Cancelled, 3=Expired)
     */
    function getCaseFull(uint256 caseId) external view override returns (
        address owner,
        string memory petName,
        uint256 bounty,
        uint8 status,
        uint256 createdAt,
        uint256 expiresAt,
        uint256 finderCount
    ) {
        require(caseId < nextCaseId, "Case does not exist");
        CaseData storage c = cases[caseId];
        uint256 count = caseFinders[caseId].length;

        return (
            c.owner,
            c.petName,
            c.bounty,
            uint8(c.status),
            c.createdAt,
            c.expiresAt,
            count
        );
    }
    
    /**
     * @notice Get total ETH held in escrow
     * @return total Total amount of ETH held for all active bounties
     */
    function getTotalEscrow() external view override returns (uint256 total) {
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (cases[i].status == CaseStatus.Active) {
                total += cases[i].bounty;
            }
        }
    }
    
    /**
     * @notice Get escrow for specific case
     */
    function getCaseEscrow(uint256 caseId) external view override returns (uint256) {
        require(caseId < nextCaseId, "Case does not exist");

        if (cases[caseId].status != CaseStatus.Active) {
            return 0;
        }
        return cases[caseId].bounty;
    }
    
    /**
     * @notice Verify case has sufficient funds
     */
    function isCaseFunded(uint256 caseId) external view override returns (bool) {
        require(caseId < nextCaseId, "Case does not exist");
        return address(this).balance >= cases[caseId].bounty;
    }
    
    /**
     * @notice Get active cases (unresolved, uncancelled, not expired)
     */
    function getActiveCases() external view override returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // First pass: count active cases
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (cases[i].status == CaseStatus.Active && block.timestamp < cases[i].expiresAt) {
                activeCount++;
            }
        }
        
        // Second pass: populate array
        uint256[] memory activeCases = new uint256[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < nextCaseId; i++) {
            if (cases[i].status == CaseStatus.Active && block.timestamp < cases[i].expiresAt) {
                activeCases[currentIndex] = i;
                currentIndex++;
            }
        }
        
        return activeCases;
    }
    
    /**
     * @notice Get cases created by a specific owner
     */
    function getCasesByOwner(address owner) external view returns (uint256[] memory) {
        return ownerCases[owner];
    }
}