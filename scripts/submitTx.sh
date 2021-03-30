#!/bin/bash

cardano-cli transaction submit \
	--tx-file tx.signed \
	--testnet-magic 1097911063
