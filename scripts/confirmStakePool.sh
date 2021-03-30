#!/bin/bash 

echo "cardano-cli query ledger-state --testnet-magic $MAGIC_NUM --mary-era \| grep publicKey \| grep \$(cardano-cli stake-pool id --cold-verification-key-file node.vkey --output-format hex)"

cardano-cli query ledger-state --testnet-magic $MAGIC_NUM --mary-era | grep publicKey | grep $(cardano-cli stake-pool id --cold-verification-key-file node.vkey --output-format hex)
