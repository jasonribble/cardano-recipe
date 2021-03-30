#!/bin/bash

cardano-cli stake-pool registration-certificate \
	--cold-verification-key-file node.vkey \
	--vrf-verification-key-file vrf.vkey \
	--pool-pledge 7000000000 \
	--pool-cost 4321000001 \
	--pool-margin 0.01 \
	--pool-reward-account-verification-key-file stake.vkey \
	--pool-owner-stake-verification-key-file stake.vkey \
	--testnet-magic 1097911063 \
	--pool-relay-ipv4 143.198.74.7 \
	--pool-relay-port 6000 \
	--metadata-url https://git.io/JmApb \
	--metadata-hash 7d1cb9720f44f4e5d23a3931028f8c9884f77fbf3521048a8022821538e1f8b4 \
	--out-file pool-registration.cert
