title: eth-community-v1
Category: About
Date: 07-08-2022

## Open Elector Design for Community Measures 

	Open communities exist to serve the common good and therefore should be given an opportunity to make collective decisions about how resources are used or allocated.   Such decisions, referred to as measures, augment participation and enable communities to become benefactors on a broader scale.
	
	This smart contract enables a measure to be proposed, voted upon and successfully fulfilled.   It also provides safety measures to prevent tampering, invalid election design or unexpected system problems from nullifying the possible benefit of a given measure.
	
	The following responsibilities are implemented as part of this contract specification.
	
	1. Contract owner is required to add an election supervisor, but has no other capabilities
	2. Arbitrary number of election supervisors are supported
	3. Supervisor may add voter by address or add voter class (by token address), but may not vote or undo votes
	4. Supervisor may remove voter or voter class for measure prior to start of voting
	5. Supervisor may begin and end the voting process
	6. Supervisor may set the fixed threshold (number) at which the measure is considered successful
	7. No changes are permitted once voting is open, the voter context is final and voter can be assured against manipulation of the rules during the voting process
	8. Voter may cast an affirmative vote once voting has been opened.   A negative or abstention vote is never required and therefore incurs no gas fees.
	9. A voter may undo their vote at any time while voting is open
	10. No votes or vote changes (undo) are allowed after voting has ended
	11. Supervisor may veto the measure prior to the end of voting to ensure the outcome of the measure aligns with the collective interest
	12. A veto measure has no result and effectively is void

