#!/bin/bash 

cardano-cli query utxo \
	--address $(cat $1) \
	--mary-era \
	--testnet-magic 1097911063 
