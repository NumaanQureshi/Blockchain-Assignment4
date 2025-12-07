// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LostPet
 * @notice Interface for the Lost Pet contract
 */
interface ILostPet {

    /// @notice Simple struct - only essential fields
    struct PetCase {
        address owner;
        string petDetails;
        uint256 bounty;
        bool isResolved;
        uint256 createdOn;
        uint256 expiresOn;
    }

    
    // --- Event Headers ---
    // Events defining the signals the contract emits
    
    /// @notice Owner creates a case for his lost pet
    /// @param caseId A unique identifier for the case 
    /// @param owner Address of the owner who created the case
    /// @param bounty Amount of ETH (in wei) locked as bounty
    /// @param petDetails Off chain string with the pet details
    /// @param expiresOn Unix timestamp of when the case expires
    event CaseCreated(
        uint256 indexed caseId, 
        address indexed owner, 
        uint256 bounty,
        string petDetails,
        uint256 expiresOn
    );

    /// @notice When someone submits a found report for a case
    /// @param caseId The lost pet case ID
    /// @param finder Address of the user who submitted the found report
    /// @param evidence Off chain string with evidence (photo, location, etc.)
    event FinderSubmitted(
        uint256 indexed caseId, 
        address indexed finder,
        string evidence
    );

    /// @notice Owner resolves the case and pays out the bounty 
    /// @param caseId The lost pet case ID
    /// @param owner Address of the pet owner
    /// @param finder Address of the finder 
    /// @param payout Amount of ETH (in wei) paid out as bounty 
    event CaseResolved(
        uint256 indexed caseId, 
        address indexed owner,
        address indexed finder,
        uint256 payout
    );

    /// @notice Owner decides to increase the bounty for an existing case
    /// @param caseId The lost pet case ID
    /// @param newBounty New total bounty amount in wei
    event IncreaseBounty(
        uint256 indexed caseId,
        uint256 newBounty
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
    
    // --- Function Headers ---

    /// @notice Create a lost pet case with bounty
    /// @param petDetails Off chain string with the pet details
    /// @return caseId The ID for a new case created
    function createCase(string calldata petDetails) external payable returns (uint256 caseId);
    
    /// @notice Owner can increase the bounty for an open case
    /// @param caseId The lost pet case ID to increase the bounty for
    function increaseBounty(uint256 caseId) external payable;
    
    /// @notice Submit yourself as a finder for a case
    /// @param caseId The lost pet case ID
    /// @param evidence Off chain string with evidence 
    function submitAsFinder(uint256 caseId, string calldata evidence) external;
    
    /// @notice Resolve case and pay bounty to a finder
    /// @param caseId The lost pet case ID
    /// @param finder Address of the finder who should receive the bounty
    function resolveCase(uint256 caseId, address finder) external;
    
    /// @notice Get finders for a case
    /// @param caseId The lost pet case ID
    /// @return finders Array of addresses that submitted as finders
    function getFinders(uint256 caseId) external view returns (address[] memory finders);

    /// @notice Check if an address is a finder for a specific case
    /// @param caseId The lost pet case ID
    /// @param finder Address of a finder to check
    /// @return isFinder True if the address is a finder for a given case
    function isFinder(uint256 caseId, address finder) external view returns (bool isFinder);

    /// @notice Get detailed information about a specific case
    /// @param caseId The lost pet case ID
    /// @return owner Address of the case owner 
    /// @return bounty The bounty amount of the case
    /// @return isResolved Has the case been resolved or not
    /// @return petDetails Off chain string with the pet details
    /// @return finderCount Number of finders submitted for this case
    function getCaseInfo(uint256 caseId) external view returns (address owner, uint256 bounty, bool isResolved, string memory petDetails, uint256 finderCount);
    
    /// @notice Cancel case and get refund
    /// @dev Only the owner of the case should be allowed to call this function
    /// @param caseId The lost pet case ID
    function cancelCase(uint256 caseId) external;
    
    /// @notice Get the total number of cases
    /// @return totalCases Total count of created cases
    function getTotalCases() external view returns (uint256 totalCases);
}