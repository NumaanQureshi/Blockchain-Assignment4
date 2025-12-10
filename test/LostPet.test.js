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
    let caseId;

    beforeEach(async () => {
      await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      caseId = 0;
    })

    it("should allow an owner to increase bounty for an active case", async () => {
      const additionalAmount = web3.utils.toWei("0.5", "ether");

      const receipt = await lostPetInstance.increaseBounty(caseId, {
        from: owner,
        value: additionalAmount
      });

      assert.equal(receipt.logs.length, 1);
      assert.equal(receipt.logs[0].event, "IncreaseBounty");
      assert.equal(receipt.logs[0].args.additionalAmount.toString(), additionalAmount.toString());

      const increasedAmount = BigInt(ONE_ETHER) + BigInt(additionalAmount);
      assert.equal(receipt.logs[0].args.newTotal.toString(), increasedAmount.toString());

      const { 1: currentBounty } = await lostPetInstance.getCaseBasic(caseId);
      assert.equal(currentBounty.toString(), increasedAmount.toString());
    });

    it("should reject bounty increase from non-owner", async () => {
      const additionalAmount = web3.utils.toWei("0.5", "ether");

      try {
        await lostPetInstance.increaseBounty(caseId, {
          from: otherAccount,
          value: additionalAmount
        });
        assert.fail("Should have thrown error");
      } catch (error) {
        assert.include(error.message, "Only case owner can increase bounty");
      }
    });

    it("should reject bounty increase with no ETH sent", async () => {
      try {
        await lostPetInstance.increaseBounty(caseId, {
          from: owner,
          value: 0
        });
        assert.fail("Should have thrown error");
      } catch (error) {
        assert.include(error.message, "Must send ETH");
      }
    });

    it("should add bounty correctly to existing bounty", async () => {
      const additional1 = web3.utils.toWei("0.3", "ether");

      await lostPetInstance.increaseBounty(caseId, {
        from: owner,
        value: additional1
      });

      const { 1: finalBounty } = await lostPetInstance.getCaseBasic(caseId);
      const expected = BigInt(ONE_ETHER) + BigInt(additional1);
      assert.equal(finalBounty.toString(), expected.toString());
    });
  });


  // Finder Submission


  describe("Finder Submission", () => {
    let caseId;

    beforeEach(async () => {
      await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      caseId = 0;
    });

    it("should allow a finder to submit evidence", async () => {
      const evidence = "https://tinyurl.com/43bddh42";

      const receipt = await lostPetInstance.submitAsFinder(caseId, evidence, {
        from: finder1
      });

      assert.equal(receipt.logs.length, 1);
      assert.equal(receipt.logs[0].event, "FinderSubmitted");
      assert.equal(receipt.logs[0].args.finder, finder1);
      assert.equal(receipt.logs[0].args.evidence, evidence);

      const isFinder = await lostPetInstance.isFinder(caseId, finder1);
      assert.equal(isFinder, true);

      const storedEvidence = await lostPetInstance.getFinderEvidence(caseId, finder1);
      assert.equal(storedEvidence, evidence);
    })

    it("should track multiple finders for the same case", async () => {
      const evidence1 = "https://tinyurl.com/43bddh42";
      const evidence2 = "https://tinyurl.com/9pnubvny";

      await lostPetInstance.submitAsFinder(caseId, evidence1, { from: finder1 });
      await lostPetInstance.submitAsFinder(caseId, evidence2, { from: finder2 });

      const isFinder1 = await lostPetInstance.isFinder(caseId, finder1);
      const isFinder2 = await lostPetInstance.isFinder(caseId, finder2);
      assert.equal(isFinder1, true);
      assert.equal(isFinder2, true);

      const finderCount = await lostPetInstance.getFinderCount(caseId);
      assert.equal(finderCount.toString(), "2");

      const finders = await lostPetInstance.getFinders(caseId);
      assert.equal(finders.length, 2);
      assert.include(finders, finder1);
      assert.include(finders, finder2);
    });

    it("should reject duplicate finder submissions", async () => {
      const evidence = "https://tinyurl.com/43bddh42";

      await lostPetInstance.submitAsFinder(caseId, evidence, { from: finder1 });

      try {
        await lostPetInstance.submitAsFinder(caseId, "https://tinyurl.com/9pnubvny", { from: finder1 });
        assert.fail("Should have thrown error");
      } catch (error) {
        assert.include(error.message, "Already submitted as finder");
      }
    });
    
    it("should reject submissions with empty evidence", async () => {
      try {
        await lostPetInstance.submitAsFinder(caseId, "", { from: finder1 });
        assert.fail("Should have thrown error");
      } catch (error) {
        assert.include(error.message, "Evidence cannot be empty");
      }
    });

    it("should return correct finder status using the isFinder() function", async () => {
      const isFinderBefore = await lostPetInstance.isFinder(caseId, finder1);
      assert.equal(isFinderBefore, false);

      await lostPetInstance.submitAsFinder(caseId, "https://tinyurl.com/9pnubvny", { from: finder1 });
      const isFinderAfter = await lostPetInstance.isFinder(caseId, finder1);
      assert.equal(isFinderAfter, true);
    });

    it("should retrieve correct evidence with getFinderEvidence()", async () => {
      const evidence = "https://tinyurl.com/9pnubvny";
    
      await lostPetInstance.submitAsFinder(caseId, evidence, { from: finder1 });
      
      const storedEvidence = await lostPetInstance.getFinderEvidence(caseId, finder1);
      assert.equal(storedEvidence, evidence);
    });
  });


  // Case Resolution


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


  describe("Case Expiry", () => {
    // TODO: Test checkAndProcessExpiry() returns false for active non-expired cases
    // TODO: Test checkAndProcessExpiry() returns true for expired cases
    // TODO: Test automatic refund to owner when case expires
    // TODO: Test case status changes to Expired
    // TODO: Test batchCheckExpiry() processes multiple cases correctly
    // TODO: Test isCaseExpired() view function returns correct status
  });


  // Escrow and Funding


  describe("Escrow & Funding", () => {
    // TODO: Test getTotalEscrow() sums all active bounties
    // TODO: Test getCaseEscrow() returns correct bounty for specific case
    // TODO: Test getCaseEscrow() returns 0 for resolved cases
    // TODO: Test getCaseEscrow() returns 0 for cancelled cases
    // TODO: Test isCaseFunded() verifies sufficient contract balance
    // TODO: Test rejection of resolution when insufficient contract balance
  });


  // View Functions - Basic (Low gas)


  describe("View Functions - Basic", () => {
    // TODO: Test getCaseBasic() returns owner, bounty, and isResolved status
    // TODO: Test getCaseBasic() uses minimal gas
    // TODO: Test getTotalCases() returns correct count
  });


  // View Functions - Detailed (Higher gas)


  describe("View Functions - Detailed", () => {
    let caseId;

    beforeEach(async () => {
      await lostPetInstance.createCase("Fluffy", {
        from: owner,
        value: ONE_ETHER
      });
      caseId = 0;

      const evidence1 = "https://tinyurl.com/43bddh42";
      const evidence2 = "https://tinyurl.com/9pnubvny";

      await lostPetInstance.submitAsFinder(caseId, evidence1, { from: finder1 });
      await lostPetInstance.submitAsFinder(caseId, evidence2, { from: finder2 });
    });

    it("should return all case details using getCaseFull() function", async () => {
      const caseDetails = await lostPetInstance.getCaseFull(caseId);

      assert.equal(caseDetails[0], owner, "Should return correct owner");
      assert.equal(caseDetails[1], "Fluffy", "Should return correct pet name");
      assert.equal(caseDetails[2].toString(), ONE_ETHER, "Should return correct bounty");
      assert.equal(caseDetails[3].toString(), "0", "Should return Active status (0)");

      const createdAt = Number(caseDetails[4]);
      const expiresAt = Number(caseDetails[5]);
      const currentTime = Math.floor(Date.now() / 1000);

      assert.isAbove(createdAt, currentTime - 60, "createdAt should be recent");
      assert.isBelow(createdAt, currentTime + 60, "createdAt should be recent");

      const expectedExpiry = createdAt + (90 * 24 * 60 * 60);
      const expiryDifference = Math.abs(expiresAt - expectedExpiry);
      assert.isBelow(expiryDifference, 60, "expiresAt should be 90 days from createdAt");

      assert.equal(caseDetails[6].toString(), "2", "Should return correct finder count");
    });
     
    it("should include correct finder count in getCaseFull()", async () => {
      let caseDetails = await lostPetInstance.getCaseFull(caseId);
      assert.equal(caseDetails[6].toString(), "2", "Should show 2 finders initially");

      await lostPetInstance.submitAsFinder(caseId, "https://tinyurl.com/9pnubvny", { from: otherAccount });

      caseDetails = await lostPetInstance.getCaseFull(caseId);
      assert.equal(caseDetails[6].toString(), "3", "Should show 3 finders after addition");

      const finderCount = await lostPetInstance.getFinderCount(caseId);
      assert.equal(caseDetails[6].toString(), finderCount.toString(), "getCaseFull finderCount should match getFinderCount()");
    });
    // TODO: Test getCaseFull() returns correct case status enum value
  });


  // Finder Query Functions


  describe("Finder Query Functions", () => {
    // TODO: Test getFinders() returns array of all finders for a case
    // TODO: Test getFinderCount() returns correct count
    // TODO: Test isFinder() correctly identifies finders
    // TODO: Test getFindersPaginated() returns correct page of finders
    // TODO: Test getFindersPaginated() returns empty array for out-of-range indices
  });


  // Active Cases


  describe("Active Cases", () => {
    // TODO: Test getActiveCases() returns only active, non-expired cases
    // TODO: Test getActiveCases() excludes resolved cases
    // TODO: Test getActiveCases() excludes cancelled cases
    // TODO: Test getActiveCases() excludes expired cases
  });


  // Error Handling and Edge Cases


  describe("Error Handling & Edge Cases", () => {
    // TODO: Test rejection of operations on non-existent cases
    // TODO: Test handling of multiple independent cases
    // TODO: Test multiple finders can be added to same case
    // TODO: Test owner can increase bounty multiple times
    // TODO: Test different owners can create different cases
  });

  // Gas Optimization and Efficiency

  describe("Gas Optimization & Efficiency", () => {
    // TODO: Compare gas costs between getCaseBasic() and getCaseFull()
    // TODO: Test pagination is more efficient than returning all finders
    // TODO: Test that state changes use minimal gas operations
  });
});
