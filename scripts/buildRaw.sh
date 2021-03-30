#!/bin/bash
cardano-cli transaction build-raw \
	--tx-in 8ef1f0f43de79e42508031be7226c64632b097ff1773968766165beb1d8aa619#0 \
	--tx-out $(cat paymentwithstake.addr)+0 \
	--ttl 0 \
	--fee 0 \
	--out-file tx.raw \
	--certificate-file pool-registration.cert \
	--certificate-file delegation.cert
