// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LostPet
 * @notice Interface for the Lost Pet contract
 */
interface LostPetInterface {

    /// @notice Simple struct - only essential fields
    struct PetCase {
        address owner;
        string petName;
        uint256 bounty;
        bool isResolved;
        bool isCancelled;
        uint256 createdAt;
        uint256 expiresAt;
        mapping(address => string) finderEvidence;
    }

    
    // --- Event Headers ---
    // Events defining the signals the contract emits
    
    /// @notice Owner creates a case for his lost pet
    /// @param caseId A unique identifier for the case 
    /// @param owner Address of the owner who created the case
    /// @param petName Name of the lost pet
    /// @param bounty Amount of ETH (in wei) locked as bounty
    /// @param expiresAt Unix timestamp of when the case expires
    event CaseCreated(
        uint256 indexed caseId, 
        address indexed owner, 
        string petName,
        uint256 bounty,
        uint256 expiresAt
    );

    /// @notice When someone submits as a finder for a case
    /// @param caseId The lost pet case ID
    /// @param finder Address of the user who submitted as finder
    /// @param evidence Proof that shows finder found pet (ex: photo link)
    event FinderSubmitted(
        uint256 indexed caseId, 
        address indexed finder,
        string evidence
    );

    /// @notice Owner resolves the case and pays out the bounty 
    /// @param caseId The lost pet case ID
    /// @param finder Address of the finder who received the bounty
    /// @param bountyAmount Amount of ETH (in wei) paid out as bounty 
    event CaseResolved(
        uint256 indexed caseId, 
        address indexed finder,
        uint256 bountyAmount
    );

    /// @notice Owner decides to increase the bounty for an existing case
    /// @param caseId The lost pet case ID
    /// @param additionalAmount Additional bounty added
    /// @param newTotal New total bounty amount in wei
    event IncreaseBounty(
        uint256 indexed caseId,
        uint256 additionalAmount,
        uint256 newTotal
    );

    /// @notice Owner cancel an unresolved case and withdraws the bounty
    /// @param caseId The lost pet case ID
    /// @param owner Address of the pet owner
    /// @param amount Amount of ETH (in wei) refunded to the owner
    event CaseCancelled(
        uint256 indexed caseId, 
        address indexed owner,
        uint256 amount
    );

    /// @notice Case expires automatically
    /// @param caseId The lost pet case ID
    /// @param owner Address of the pet owner
    /// @param amount Amount of ETH (in wei) refunded to the owner
    event CaseExpired(
        uint256 indexed caseId, 
        address indexed owner,
        uint256 amount
    );
    
    // --- Function Headers ---
    
    // OWNER-ONLY FUNCTIONS
    /// @notice Create a lost pet case with bounty
    /// @dev Only the creator becomes the owner
    /// @param petName Name of the lost pet
    /// @return caseId The ID for a new case created
    function createCase(string calldata petName) external payable returns (uint256 caseId);
    
    /// @notice Owner can increase the bounty for an open case
    /// @dev Only case owner can call this function
    /// @param caseId The lost pet case ID to increase the bounty for
    function increaseBounty(uint256 caseId) external payable;
    
    /// @notice Resolve case and pay bounty to a finder
    /// @dev Only case owner can call this function
    /// @param caseId The lost pet case ID
    /// @param finderIndex Index of the finder in the finders array
    function resolveCase(uint256 caseId, uint256 finderIndex) external;
    
    /// @notice Cancel case and get refund
    /// @dev Only the owner of the case should be allowed to call this function
    /// @param caseId The lost pet case ID
    function cancelCase(uint256 caseId) external;
    
    // PUBLIC FUNCTIONS
    /// @notice Submit yourself as a finder for a case
    /// @param caseId The lost pet case ID
    /// @param evidence Proof that shows finder found pet (ex: photo link)
    function submitAsFinder(uint256 caseId, string calldata evidence) external;
    
    /// @notice Check and process expired cases
    /// @param caseId The lost pet case ID
    /// @return processed True if case was expired and processed
    function checkAndProcessExpiry(uint256 caseId) external returns (bool processed);
    
    /// @notice Batch check multiple cases for expiry
    /// @param caseIds Array of case IDs to check
    /// @return processedCount Number of cases that were expired and processed
    function batchCheckExpiry(uint256[] calldata caseIds) external returns (uint256 processedCount);
    
    // VIEW FUNCTIONS - BASIC (Low gas)
    /// @notice Get basic case information (low gas)
    /// @param caseId The lost pet case ID
    /// @return owner Address of the case owner 
    /// @return bounty The bounty amount of the case
    /// @return isResolved Has the case been resolved or not
    function getCaseBasic(uint256 caseId) external view returns (address owner, uint256 bounty, bool isResolved);
    
    /// @notice Get the total number of cases
    /// @return totalCases Total count of created cases
    function getTotalCases() external view returns (uint256 totalCases);
    
    /// @notice Check if case is expired
    /// @param caseId The lost pet case ID
    /// @return isExpired True if the case has expired
    function isCaseExpired(uint256 caseId) external view returns (bool isExpired);
    
    // VIEW FUNCTIONS - FINDERS (Clear display)
    /// @notice Get finders for a case
    /// @param caseId The lost pet case ID
    /// @return finders Array of addresses that submitted as finders
    function getFinders(uint256 caseId) external view returns (address[] memory finders);
    
    /// @notice Check if an address is a finder for a specific case
    /// @param caseId The lost pet case ID
    /// @param finder Address of a finder to check
    /// @return isFinder True if the address is a finder for a given case
    function isFinder(uint256 caseId, address finder) external view returns (bool isFinder);
    
    /// @notice Get paginated finders (gas efficient for large lists)
    /// @param caseId The lost pet case ID
    /// @param startIndex Starting index in finders array
    /// @param count Number of finders to retrieve
    /// @return finders Slice of finder addresses
    function getFindersPaginated(uint256 caseId, uint256 startIndex, uint256 count) 
        external 
        view 
        returns (address[] memory finders);

    /// @notice View the evidence submitted by a specific finder
    /// @param caseId The lost pet case ID
    /// @param finder Address of a finder to check
    /// @return evidence The string containing the evidence submitted by the finder
    function getFinderEvidence(uint256 caseID, address finder)
        external
        view
        returns (string memory evidence);
    
    // VIEW FUNCTIONS - DETAILED (Higher gas)
    /// @notice Get full case details (higher gas)
    /// @param caseId The lost pet case ID
    /// @return owner Address of the case owner
    /// @return petName Name of the lost pet
    /// @return bounty The bounty amount of the case
    /// @return isResolved Has the case been resolved or not
    /// @return isCancelled Has the case been cancelled or not
    /// @return createdAt When the case was created
    /// @return expiresAt When the case expires
    /// @return finderCount Number of finders submitted for this case
    function getCaseFull(uint256 caseId) external view returns (
        address owner,
        string memory petName,
        uint256 bounty,
        bool isResolved,
        bool isCancelled,
        uint256 createdAt,
        uint256 expiresAt,
        uint256 finderCount
    );
    
    // VIEW FUNCTIONS - WALLET/ESCROW
    /// @notice Get total ETH held in escrow
    /// @return total Total amount of ETH held for all active bounties
    function getTotalEscrow() external view returns (uint256 total);
    
    /// @notice Get escrow for specific case
    /// @param caseId The lost pet case ID
    /// @return escrowAmount Amount of ETH held for this case's bounty
    function getCaseEscrow(uint256 caseId) external view returns (uint256 escrowAmount);
    
    /// @notice Verify case has sufficient funds
    /// @param caseId The lost pet case ID
    /// @return isFunded True if contract holds sufficient ETH for bounty
    function isCaseFunded(uint256 caseId) external view returns (bool isFunded);
}