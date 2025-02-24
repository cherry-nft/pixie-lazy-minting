#!/bin/bash

# Update OpenZeppelin imports
find . -type f -name "*.sol" -exec sed -i 's|@openzeppelin/contracts-upgradeable|@openzeppelin-upgradeable/contracts|g' {} + 