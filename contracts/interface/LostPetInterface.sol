// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LostPet
 * @notice Interface for the Lost Pet contract
 */
interface ILostPet {

    // Simple struct - only essential fields
    struct PetCase {
        address owner;
        string petName;
        uint256 bounty;
        bool isResolved;
    }

    // --- Event Headers ---

    // Events defining the signals the contract emits
    event CaseCreated(uint256 caseId, address owner, string petName);
    event CaseResolved(uint256 caseId, address finder);
    
    // --- Function Headers ---

    /**
     * @notice Create a lost pet case with bounty
     */
    function createCase(string calldata petName) external payable returns (uint256);
    
    /**
     * @notice Submit yourself as a finder for a case
     */
    function submitAsFinder(uint256 caseId) external;
    
    /**
     * @notice Resolve case and pay bounty to a finder
     */
    function resolveCase(uint256 caseId, uint256 finderIndex) external;
    
    /**
     * @notice Get finders for a case
     */
    function getFinders(uint256 caseId) external view returns (address[] memory);
    
    /**
     * @notice Cancel case and get refund
     */
    function cancelCase(uint256 caseId) external;
    
    /**
     * @notice Get the total number of cases
     */
    function getTotalCases() external view returns (uint256);
}