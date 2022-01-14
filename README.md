# Daoification of dOrg

This repository contains contracts and scripts for the daoification efforts of dOrg.

## Testing

For testing please add one or two accounts to the *.env* file in the root-directory.

<!-- 
```
ADDRESS_ALICE
ADDRESS_BOB
ADDRESS_CHARLIE
ADDRESS_DORG

PRIVATE_KEY_ALICE
PRIVATE_KEY_BOB
PRIVATE_KEY_CHARLIE
PRIVATE_KEY_DORG
``` -->


```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```
