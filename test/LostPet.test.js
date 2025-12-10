const LostPet = artifacts.require("LostPet");

// Helper constants
const MIN_BOUNTY = web3.utils.toWei("0.001", "ether");
const ONE_ETHER = web3.utils.toWei("1", "ether");
const DEFAULT_EXPIRY_DAYS = 90 * 24 * 60 * 60; // 90 days in seconds

// Case status enum
const CaseStatus = {
  Active: 0,
  Resolved: 1,
  Cancelled: 2,
  Expired: 3
};

contract("LostPet", (accounts) => {
  const [owner, finder1, finder2, otherAccount] = accounts;

  let lostPetInstance;

  // Helper to advance time and mine a block
  async function increaseTime(seconds) {
    await new Promise((resolve, reject) => {
      web3.currentProvider.send({
        jsonrpc: '2.0',
        method: 'evm_increaseTime',
        params: [seconds],
        id: new Date().getTime()
      }, (err, res) => err ? reject(err) : resolve(res));
    });
    await new Promise((resolve, reject) => {
      web3.currentProvider.send({
        jsonrpc: '2.0',
        method: 'evm_mine',
        params: [],
        id: new Date().getTime() + 1
      }, (err, res) => err ? reject(err) : resolve(res));
    });
  }

  beforeEach(async () => {
    lostPetInstance = await LostPet.new();
  });


  // Creating Cases

  
  describe("Case Creation", () => {
    it("should create a case with bounty and emit CaseCreated event", async () => {
      const petName = "Fluffy";
      const receipt = await lostPetInstance.createCase(petName, { 
        from: owner, 
        value: ONE_ETHER 
      });

      // Verify event was emitted
      assert.equal(receipt.logs.length, 1);
      assert.equal(receipt.logs[0].event, "CaseCreated");
      assert.equal(receipt.logs[0].args.caseId, 0);
      assert.equal(receipt.logs[0].args.owner, owner);
      assert.equal(receipt.logs[0].args.petName, petName);
      assert.equal(receipt.logs[0].args.bounty.toString(), ONE_ETHER);
    });

    it("should increment case IDs properly", async () => {
      const receipt1 = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      assert.equal(receipt1.logs[0].args.caseId, 0, "First case should have ID 0");

      const receipt2 = await lostPetInstance.createCase("Luna", {
        from: owner,
        value: ONE_ETHER
      });
      assert.equal(receipt2.logs[0].args.caseId, 1, "Second case should have ID 1");

      const totalCases = await lostPetInstance.getTotalCases();
      assert.equal(totalCases.toString(), "2", "Should be 2 cases in total");
    });
    
    it("should reject cases where bounty is below minimum (0.001 ETH)", async () => {
      const belowMinBounty = web3.utils.toWei("0.0005", "ether");
     
      try {
        await lostPetInstance.createCase("Ruby", { 
          from: owner, 
          value: belowMinBounty 
        });
        assert.fail("Should have thrown error");
      } catch (error) {
        assert.include(error.message, "Bounty must be at least 0.001 ETH");
      }
    });
    
    it("should reject cases with empty pet names", async () => {
      try {
        await lostPetInstance.createCase ("", {
          from: owner,
          value: ONE_ETHER
        });
        assert.fail("Should have thrown error");
      } catch(error) {
        assert.include(error.message, "Pet name cannot be empty");
      }
    });

    it("should set expiry date to 90 days from creation date", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });

      const caseId = receipt.logs[0].args.caseId;
      const caseDetails = await lostPetInstance.getCaseFull(caseId);

      const createdAt = caseDetails[4];
      const expiresAt = caseDetails[5];
      const expectedExpiryDate = BigInt(createdAt.toString()) + BigInt(DEFAULT_EXPIRY_DAYS);

      assert.equal(expiresAt.toString(), expectedExpiryDate.toString(), "Expiry date should be 90 days from creation");
    })
  });


  // Increasing Bounty


  describe("Increasing Bounty", () => {
    // TODO: Test increasing bounty for an active case
    // TODO: Test rejection of bounty increase from non-owner
    // TODO: Test rejection of bounty increase with no ETH sent
    // TODO: Test bounty is added correctly to existing bounty
  });


  // Finder Submission


  describe("Finder Submission", () => {
    // TODO: Test allowing a finder to submit evidence
    // TODO: Test tracking multiple finders for the same case
    // TODO: Test rejection of duplicate finder submissions
    // TODO: Test rejection of submissions with empty evidence
    // TODO: Test isFinder() function returns correct status
    // TODO: Test getFinderEvidence() retrieves correct evidence
  });


  // Case Reolution


  describe("Case Resolution", () => {
    // TODO: Test resolving a case and paying bounty to finder
    // TODO: Test updating case status to Resolved after payment
    // TODO: Test rejection of resolution from non-owner
    // TODO: Test rejection of resolution with invalid finder index
    // TODO: Test rejection of resolution if case has no finders
    // TODO: Test that bounty is correctly transferred to finder address
  });


  // Case Cancellation


  describe("Case Cancellation", () => {
    // TODO: Test rejection of cancellation before 7 days have passed
    // TODO: Test rejection of cancellation if finders already submitted
    // TODO: Test rejection of cancellation from non-owner
    // TODO: Test successful cancellation and refund after 7 days
    // TODO: Test case status changes to Cancelled
  });


  // Case Expiry
  // This should test the following:
  // - A case's status can change to Expired
  // - Refunds are automatically sent to owner when case expires
  // - checkAndProcessExpiry() returns false for active non-expired cases, and true for expired cases
  // - batchCheckExpiry() processes multiple cases correctly
  // - isCaseExpired() view function returns correct status


  describe("Case Expiry", () => {
    it("should return false for active non-expired cases", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      const result = await lostPetInstance.checkAndProcessExpiry.call(caseId);
      assert.equal(result, false, "Should return false for non-expired case");
    });

    it("should return true for expired cases", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Advance time beyond expiry
      await increaseTime(DEFAULT_EXPIRY_DAYS + 1);

      const result = await lostPetInstance.checkAndProcessExpiry.call(caseId);
      assert.equal(result, true, "Should return true for expired case");
    });

    it("should refund bounty to owner when case expires", async () => {
      const initialBalance = await web3.eth.getBalance(owner);
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Advance time beyond expiry
      await increaseTime(DEFAULT_EXPIRY_DAYS + 1);

      await lostPetInstance.checkAndProcessExpiry(caseId);
      const finalBalance = await web3.eth.getBalance(owner);

      assert(BigInt(finalBalance) > BigInt(initialBalance) - BigInt(ONE_ETHER), "Owner should receive refund");
    });

    it("should change case status to Expired", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Advance time beyond expiry
      await increaseTime(DEFAULT_EXPIRY_DAYS + 1);

      await lostPetInstance.checkAndProcessExpiry(caseId);
      const caseDetails = await lostPetInstance.getCaseFull(caseId);

      assert.equal(caseDetails.status, CaseStatus.Expired, "Case status should be Expired");
    });

    it("should process multiple cases correctly with batchCheckExpiry()", async () => {
      const receipt1 = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId1 = receipt1.logs[0].args.caseId;

      const receipt2 = await lostPetInstance.createCase("Buddy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId2 = receipt2.logs[0].args.caseId;

      // Advance time beyond expiry
      await increaseTime(DEFAULT_EXPIRY_DAYS + 1);

      // Execute the batch transaction to process expiries
      await lostPetInstance.batchCheckExpiry([caseId1, caseId2]);

      // Verify both cases changed status to Expired
      const caseDetails1 = await lostPetInstance.getCaseFull(caseId1);
      const caseDetails2 = await lostPetInstance.getCaseFull(caseId2);

      assert.equal(caseDetails1.status, CaseStatus.Expired, "First case should be Expired");
      assert.equal(caseDetails2.status, CaseStatus.Expired, "Second case should be Expired");
    });

    it("should correctly identify expired cases with isCaseExpired()", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      let isExpired = await lostPetInstance.isCaseExpired(caseId);
      assert.equal(isExpired, false, "Should not be expired initially");

      // Advance time beyond expiry
      await web3.currentProvider.send({jsonrpc: '2.0', method: 'evm_increaseTime', params: [DEFAULT_EXPIRY_DAYS + 1], id: 0}, () => {});
      await web3.currentProvider.send({jsonrpc: '2.0', method: 'evm_mine', params: [], id: 1}, () => {});

      isExpired = await lostPetInstance.isCaseExpired(caseId);
      assert.equal(isExpired, true, "Should be expired after time advancement");
    });
  });


  // Escrow and Funding


  describe("Escrow & Funding", () => {
    // Tests escrow and funding features by showing:
    // - getTotalEscrow() sums all active bounties
    // - getCaseEscrow() returns correct bounty for specific case
    // - getCaseEscrow() returns 0 for resolved cases and cancelled cases
    // - isCaseFunded() verifies sufficient contract balance
    // - Resolutions will reject when there is an insufficient contract balance
    it("should sum all active bounties with getTotalEscrow()", async () => {
      await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      await lostPetInstance.createCase("Buddy", {
        from: owner,
        value: web3.utils.toWei("0.5", "ether")
      });

      const totalEscrow = await lostPetInstance.getTotalEscrow();
      const expectedTotal = BigInt(ONE_ETHER) + BigInt(web3.utils.toWei("0.5", "ether"));

      assert.equal(totalEscrow.toString(), expectedTotal.toString(), "Total escrow should sum all bounties");
    });

    it("should return correct bounty for specific case with getCaseEscrow()", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      const caseEscrow = await lostPetInstance.getCaseEscrow(caseId);
      assert.equal(caseEscrow.toString(), ONE_ETHER, "Case escrow should match bounty");
    });

    it("should return 0 escrow for resolved cases", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Submit finder
      await lostPetInstance.submitAsFinder(caseId, "Found the pet!", { from: finder1 });

      // Advance time to allow resolution
      await increaseTime(2 * 24 * 60 * 60);

      // Resolve case
      await lostPetInstance.resolveCase(caseId, 0, { from: owner });

      const caseEscrow = await lostPetInstance.getCaseEscrow(caseId);
      assert.equal(caseEscrow.toString(), "0", "Resolved case should have 0 escrow");
    });

    it("should return 0 escrow for cancelled cases", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Advance time to allow cancellation (after 7 days)
      await increaseTime(7 * 24 * 60 * 60 + 1);

      // Cancel case
      await lostPetInstance.cancelCase(caseId, { from: owner });

      const caseEscrow = await lostPetInstance.getCaseEscrow(caseId);
      assert.equal(caseEscrow.toString(), "0", "Cancelled case should have 0 escrow");
    });

    it("should verify sufficient contract balance with isCaseFunded()", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      const isFunded = await lostPetInstance.isCaseFunded(caseId);
      assert.equal(isFunded, true, "Case should be funded");
    });
  });


  // View Functions - Basic (Low gas)
  // Tests the basic view function by showing:
  // - getCaseBasic() returns owner, bounty, and isResolved status
  // - getCaseBasic() uses minimal gas
  // - getTotalCases() returns correct count

  describe("View Functions - Basic", () => {
    it("should return owner, bounty, and isResolved status", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      const caseBasic = await lostPetInstance.getCaseBasic(caseId);
      assert.equal(caseBasic.owner, owner, "Owner should match");
      assert.equal(caseBasic.bounty.toString(), ONE_ETHER, "Bounty should match");
      assert.equal(caseBasic.isResolved, false, "Should not be resolved initially");
    });

    it("should return correct count with getTotalCases()", async () => {
      await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      await lostPetInstance.createCase("Buddy", {
        from: owner,
        value: ONE_ETHER
      });

      const totalCases = await lostPetInstance.getTotalCases();
      assert.equal(totalCases.toString(), "2", "Total cases should be 2");
    });
  });


  // View Functions - Detailed (Higher gas)
  // Tests the detailed view function by showing:
  // - getCaseFull() returns all case details
  // - getCaseFull() returns the correct case status enum value, and the finder count

  describe("View Functions - Detailed", () => {
    it("should return all case details", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      const caseFull = await lostPetInstance.getCaseFull(caseId);
      assert.equal(caseFull.owner, owner, "Owner should match");
      assert.equal(caseFull.petName, "Fluffy", "Pet name should match");
      assert.equal(caseFull.bounty.toString(), ONE_ETHER, "Bounty should match");
      assert.isAbove(parseInt(caseFull.createdAt), 0, "CreatedAt should be set");
      assert.isAbove(parseInt(caseFull.expiresAt), parseInt(caseFull.createdAt), "ExpiresAt should be after createdAt");
    });

    it("should return correct case status enum value and finder count", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Submit a finder
      await lostPetInstance.submitAsFinder(caseId, "Found the pet!", { from: finder1 });

      const caseFull = await lostPetInstance.getCaseFull(caseId);
      assert.equal(caseFull.status, CaseStatus.Active, "Status should be Active (0)");
      assert.equal(caseFull.finderCount.toString(), "1", "Finder count should be 1");
    });
  });


  // Finder Query Functions
  // Tests the functionality of finder related functions by showing:
  // - getFinders() returns an array of all finders for a case
  // - getFinderCount() returns the correct count
  // - isFinder() identifies finders
  // - getFindersPaginated() returns the correct page of finders
  // - getFindersPaginated() returns an empty array for out-of-range indices


  describe("Finder Query Functions", () => {
    it("should return all finders with getFinders()", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      await lostPetInstance.submitAsFinder(caseId, "Evidence 1", { from: finder1 });
      await lostPetInstance.submitAsFinder(caseId, "Evidence 2", { from: finder2 });

      const finders = await lostPetInstance.getFinders(caseId);
      assert.equal(finders.length, 2, "Should have 2 finders");
      assert.equal(finders[0], finder1, "First finder should match");
      assert.equal(finders[1], finder2, "Second finder should match");
    });

    it("should return correct count with getFinderCount()", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      await lostPetInstance.submitAsFinder(caseId, "Evidence 1", { from: finder1 });
      await lostPetInstance.submitAsFinder(caseId, "Evidence 2", { from: finder2 });

      const count = await lostPetInstance.getFinderCount(caseId);
      assert.equal(count.toString(), "2", "Finder count should be 2");
    });

    it("should identify finders correctly with isFinder()", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      await lostPetInstance.submitAsFinder(caseId, "Evidence", { from: finder1 });

      const isFinder1 = await lostPetInstance.isFinder(caseId, finder1);
      const isFinder2 = await lostPetInstance.isFinder(caseId, finder2);

      assert.equal(isFinder1, true, "finder1 should be identified as finder");
      assert.equal(isFinder2, false, "finder2 should not be identified as finder");
    });

    it("should return correct page with getFindersPaginated()", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      await lostPetInstance.submitAsFinder(caseId, "Evidence 1", { from: finder1 });
      await lostPetInstance.submitAsFinder(caseId, "Evidence 2", { from: finder2 });
      await lostPetInstance.submitAsFinder(caseId, "Evidence 3", { from: otherAccount });

      const page1 = await lostPetInstance.getFindersPaginated(caseId, 0, 2);
      assert.equal(page1.length, 2, "First page should have 2 finders");
      assert.equal(page1[0], finder1, "First finder on page 1 should match");
      assert.equal(page1[1], finder2, "Second finder on page 1 should match");

      const page2 = await lostPetInstance.getFindersPaginated(caseId, 2, 2);
      assert.equal(page2.length, 1, "Second page should have 1 finder");
      assert.equal(page2[0], otherAccount, "Finder on page 2 should match");
    });

    it("should return empty array for out-of-range indices", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      await lostPetInstance.submitAsFinder(caseId, "Evidence", { from: finder1 });

      const finders = await lostPetInstance.getFindersPaginated(caseId, 10, 5);
      assert.equal(finders.length, 0, "Should return empty array for out-of-range indices");
    });
  });


  // Active Cases
  // Tests the functionality of getActiveCases() by:
  // - Returning only active, non-expired cases
  // - Excludes resolved cases, cancelled cases, and expired cases

  describe("Active Cases", () => {
    it("should return only active, non-expired cases", async () => {
      const receipt1 = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId1 = receipt1.logs[0].args.caseId;

      const receipt2 = await lostPetInstance.createCase("Buddy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId2 = receipt2.logs[0].args.caseId;

      const activeCases = await lostPetInstance.getActiveCases();
      assert.equal(activeCases.length, 2, "Should have 2 active cases");
      assert.include(activeCases.map(id => id.toString()), caseId1.toString(), "Should include case 1");
      assert.include(activeCases.map(id => id.toString()), caseId2.toString(), "Should include case 2");
    });

    it("should exclude resolved cases", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Submit finder and resolve
      await lostPetInstance.submitAsFinder(caseId, "Evidence", { from: finder1 });
      await increaseTime(2 * 24 * 60 * 60);
      await lostPetInstance.resolveCase(caseId, 0, { from: owner });

      const activeCases = await lostPetInstance.getActiveCases();
      assert.equal(activeCases.length, 0, "Should have no active cases after resolution");
    });

    it("should exclude cancelled cases", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Cancel case
      await increaseTime(7 * 24 * 60 * 60 + 1);
      await lostPetInstance.cancelCase(caseId, { from: owner });

      const activeCases = await lostPetInstance.getActiveCases();
      assert.equal(activeCases.length, 0, "Should have no active cases after cancellation");
    });

    it("should exclude expired cases", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      const caseId = receipt.logs[0].args.caseId;

      // Advance time past expiry
      await increaseTime(DEFAULT_EXPIRY_DAYS + 1);

      const activeCases = await lostPetInstance.getActiveCases();
      assert.equal(activeCases.length, 0, "Should have no active cases after expiry");
    });
  });


  // Error Handling and Edge Cases
  // This should test the following:
  // - The rejection of operations on any non-existent cases
  // - Handling of multiple independent cases
  // - Adding multiple finders to the same case
  // - Owner's ability to increase bounty multiple times
  // - Different owners can create different cases ()

  describe("Error Handling & Edge Cases", () => {
    it("should reject operations on non-existent case", async () => {
      try {
        await lostPetInstance.getCaseBasic(999);
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert(error.message.includes("Case does not exist"));
      }
    });

    it("should reject finder submission on non-existent case", async () => {
      try {
        await lostPetInstance.submitAsFinder(999, "Evidence", { from: finder1 });
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert(error.message.includes("Case does not exist"));
      }
    });

    it("should handle multiple cases independently", async () => {
      await lostPetInstance.createCase("Fluffy", { 
        from: owner, 
        value: ONE_ETHER 
      });
      await lostPetInstance.createCase("Buddy", { 
        from: finder1, 
        value: web3.utils.toWei("0.5", "ether") 
      });

      const case0 = await lostPetInstance.getCaseBasic(0);
      const case1 = await lostPetInstance.getCaseBasic(1);

      assert.equal(case0.owner, owner);
      assert.equal(case1.owner, finder1);
      assert.equal(case0.bounty.toString(), ONE_ETHER);
      assert.equal(case1.bounty.toString(), web3.utils.toWei("0.5", "ether"));
    });
  });

  // Gas Optimization and Efficiency
  // This should test the following:
  // - Comparison between the gas costs of getCaseBasic() and getCaseFull()
  // - Proving our test pagination function is more efficient than returning all finders
  // - State changes use less gas operations

  describe("Gas Optimization & Efficiency", () => {
    it("should use less gas for basic queries than full queries", async () => {
      await lostPetInstance.createCase("Fluffy", { 
        from: owner, 
        value: ONE_ETHER 
      });

      // Measure gas for basic query
      const basicGasEstimate = await lostPetInstance.getCaseBasic.estimateGas(0);

      // Measure gas for full query
      const fullGasEstimate = await lostPetInstance.getCaseFull.estimateGas(0);

      // Basic should use less gas than full
      assert.isBelow(parseInt(basicGasEstimate), parseInt(fullGasEstimate), "Basic query should use less gas than full query");
    });

    it("should prove pagination is more efficient than returning all finders", async () => {
      const receipt = await lostPetInstance.createCase("Fluffy", { 
        from: owner, 
        value: ONE_ETHER 
      });
      const caseId = receipt.logs[0].args.caseId;

      // Add multiple finders
      for (let i = 0; i < 5; i++) {
        await lostPetInstance.submitAsFinder(caseId, `Evidence ${i}`, { from: accounts[i] });
      }

      // Measure gas for getFinders (all)
      const allFindersGasEstimate = await lostPetInstance.getFinders.estimateGas(caseId);

      // Measure gas for paginated (subset)
      const paginatedGasEstimate = await lostPetInstance.getFindersPaginated.estimateGas(caseId, 0, 2);

      // Paginated should use less gas than getting all
      assert.isBelow(parseInt(paginatedGasEstimate), parseInt(allFindersGasEstimate), "Paginated query should use less gas than returning all finders");
    });
  });
});
