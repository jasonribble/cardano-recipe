#!/bin/bash 

cardano-cli transaction calculate-min-fee \
	--tx-body-file tx.raw \
	--tx-in-count 1 \
	--tx-out-count 1 \
	--testnet-magic 1097911063 \
	--witness-count 1 \
	--byron-witness-count 0 \
	--protocol-params-file protocol.json
