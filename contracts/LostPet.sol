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
    
    // Simple struct - only essential fields
    struct PetCase {
        address owner;
        string petName;
        uint256 bounty;
        bool isResolved;
    }
    
    // Only essential events
    event CaseCreated(uint256 caseId, address owner, string petName);
    event CaseResolved(uint256 caseId, address finder);
    
    /**
     * @notice Create a lost pet case with bounty
     */
    function createCase(string calldata petName) external payable {
        // TODO: Check that bounty is at least 0.001 ETH - STARTED
        require(msg.value >= 0.001 ether, "Bounty must be at least 0.001 ETH");
        
        // TODO: Check pet name is not empty - STARTED
        require(bytes(petName).length > 0, "Pet name cannot be empty");
        
        uint256 caseId = nextCaseId;
        nextCaseId++;
        
        cases[caseId] = PetCase({
            owner: msg.sender,
            petName: petName,
            bounty: msg.value,
            isResolved: false
        });
        
        emit CaseCreated(caseId, msg.sender, petName);
    }
    
    /**
     * @notice Submit yourself as a finder for a case
     */
    function submitAsFinder(uint256 caseId) external {
        // TODO: Check case exists and is not resolved - STARTED
        require(caseId < nextCaseId, "Case does not exist");
        require(!cases[caseId].isResolved, "Case already resolved");
        
        // TODO: Check finder not already submitted
        // Need to loop through caseFinders[caseId] and check if msg.sender is already there
        
        caseFinders[caseId].push(msg.sender);
    }
    
    /**
     * @notice Resolve case and pay bounty to a finder
     */
    function resolveCase(uint256 caseId, uint256 finderIndex) external {
        // TODO: Check only owner can call this - STARTED
        require(msg.sender == cases[caseId].owner, "Only case owner can resolve");
        
        // TODO: Check case is not already resolved - STARTED
        require(!cases[caseId].isResolved, "Case already resolved");
        
        // TODO: Check finder index is valid - STARTED
        require(finderIndex < caseFinders[caseId].length, "Invalid finder index");
        
        address finder = caseFinders[caseId][finderIndex];
        uint256 bounty = cases[caseId].bounty;
        
        // Update state before sending money
        cases[caseId].isResolved = true;
        cases[caseId].bounty = 0;
        
        // Send bounty to finder
        payable(finder).transfer(bounty);
        
        emit CaseResolved(caseId, finder);
    }
    
    /**
     * @notice Get finders for a case
     */
    function getFinders(uint256 caseId) external view returns (address[] memory) {
        return caseFinders[caseId];
    }
    
    /**
     * @notice Cancel case and get refund
     */
    function cancelCase(uint256 caseId) external {
        // TODO: Only owner can cancel - STARTED
        require(msg.sender == cases[caseId].owner, "Only owner can cancel");
        
        // TODO: Only if no finders yet - STARTED
        require(caseFinders[caseId].length == 0, "Cannot cancel - finders already submitted");
        
        // TODO: Refund bounty
        // Need to get the bounty amount and send it back to owner
        // Remember to update case state (set isResolved? or add new field like isCancelled?)
        
        revert("Refund logic not implemented yet");
    }
    
    /**
     * @notice Get total number of cases
     */
    function getTotalCases() external view returns (uint256) {
        return nextCaseId;
    }
}