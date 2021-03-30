#!/bin/bash 

cardano-cli transaction sign \
	--tx-body-file tx.raw \
	--signing-key-file payment.skey \
	--signing-key-file stake.skey \
	--signing-key-file node.skey \
	--testnet-magic 1097911063 \
	--out-file tx.signed
