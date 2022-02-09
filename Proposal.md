    # Daoification

    | Budget | Term | Lead | Builders |
    |-|-|-|-|
    | 5,200 USDC + 2,000 DORG | 6 weeks (Feb 5 - Mar 19) | Andrei | Andrei, Leo |


    ## Summary

    The solution incorporates some of the work done on dOrg app, and addresses the same pain points, with the added value proposition of commercial relevance. We’re drawing from the existing operating model of dOrg [see  here](https://drive.google.com/file/d/1GVi5_Vus_CreBrhdNfb8aAoQMOLrMC4x/view?ts=61fdbe36 ) to develop a web3 tool that manages all administrative processes in a trustless setting, and streamlines the UX for both internal and external stakeholders. A transparent and immutable framework devised to serve as a single source of truth for builders, clients as well as the public at large. 

    The solution consists of a set of contracts - https://github.com/dOrgTech/daoification and a web client https://github.com/dOrgTech/daoification-web. Here is an overview: https://www.youtube.com/watch?v=egpWANkzUNE
    We started working on this on Jan 7, and implemented the Client Projects section in both contracts and webapp (minus web integration). Here is a walkthrough of that: https://www.youtube.com/watch?v=enXRPkC1y8k



    ## Why build this

    1. **Safe expansion**. A fully trustless workflow allows dOrg to rapidly expand without relying so much on stringent vetting of new members. The proposed mechanism can only be used as prescribed through democratic consensus, in matters of internal administration as well as for client projects.The outcome of any given voting action is automatically enforced, eliminating social exploits.

    2. **Launch a commercial product**. DAOs are to 2022 what NFTs were to 2021. Interest for this vertical is spiking and we are in a privileged position to draw upon our real-world experience, implement tight feedback loops and iterate quickly to put out a superior product in terms of utility. 

    3. **Time-efficiency**. Centralizing all activity into a single distributed app declutters the operating model and makes it easier for new members to familiarize themselves with the processes.
    Automations include: 
    allocating reputation tokens pertaining to a builder’s earnings
    gas reimbursements
    allocating funds according to outcome of proposals 
    batch payments for internal roles and for teams working on client projects
    The solution is deprecating Gnosis Safe and Snapshot and removes the need for having treasury signers.


    ## Objective and estimated effort

    The goal for this 6-week period is to deliver a functional MVP deployed on testnet.


    | **Task** | **Hours** * **Builder** |
    |---|---|
    |Implement the project flow for internal affairs (departments), contract-side |12h * Leo + 12h * Andrei|
    |Client-side implementation of internal affairs section | 40h * Andrei|
    |Manual testing of the contracts|6 * Leo + 6 * Andrei|
    |Web3 Integration. Hook up contract functionality UI/UX| 50 * Andrei |
    |Automated testing with Hardhat (typescript) | 30 * Leo |


    ## Rates

    | **Builder** | **USDC / hour** | **total hours** | **total USDC** | **total DORG** |
    |---|---|---|---|---|
    | Leo | 50 |  48 | 2400 | 1000 |
    | Andrei | 25 | 108 | 2700 |1000|
    | Total | - | 161 | 5100 | 2000|

    Payments will be broken down into two milestones: 
    - First 3 tasks - 4 weeks
    - Last 2 tasks - 2 weeks

    Project board: https://trello.com/b/zcUSN1Nj/daoification
