#!/usr/bin/env bash

. scripts/internal/envVar.sh

CONTAINER_CLI="docker"
CONTAINER_CLI_COMPOSE="docker-compose"

if ! $CONTAINER_CLI info > /dev/null 2>&1 ; then
    echo "$CONTAINER_CLI network is required to be running to create a channel"
    exit 1
fi

: ${CHANNEL_NAME:="mychannel"}
DELAY="3"
MAX_RETRY="2"
VERBOSE="false"
BFT=0

mkdir channel-artifacts

createChannelGenesisBlock() {
    setGlobals 1
	set -x
	configtxgen -profile ChannelUsingRaft -outputBlock ./channel-artifacts/${CHANNEL_NAME}.block -channelID $CHANNEL_NAME
	res=$?
	{ set +x; } 2>/dev/null
    verifyResult $res "Failed to generate channel configuration transaction..."
}

createChannel() {
	local rc=1
	local COUNTER=1

	echo "Adding orderers"
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
    	. scripts/internal/orderer.sh ${CHANNEL_NAME}> /dev/null 2>&1

		res=$?
		{ set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done

	verifyResult $res "Channel creation failed"
}

joinChannel(){
	ORG=$1
  	FABRIC_CFG_PATH=$PWD/compose/docker/peercfg/
  	setGlobals $ORG
	local rc=1
	local COUNTER=1
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    	sleep $DELAY
    	set -x
    	peer channel join -b $BLOCKFILE
    	res=$?
    	{ set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done

	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

setAnchorPeer(){
	ORG=$1
  	. scripts/internal/setAnchorPeer.sh $ORG $CHANNEL_NAME
}

BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"
echo "Generating channel genesis block '${CHANNEL_NAME}.block'"
FABRIC_CFG_PATH=${PWD}/configtx
export FABRIC_CFG_PATH=${PWD}/configtx
createChannelGenesisBlock

echo "Creating channel ${CHANNEL_NAME}"
createChannel

echo "Joining org1 peer to the channel..."
joinChannel 1
echo "Joining org2 peer to the channel..."
joinChannel 2

echo "Setting anchor peer for org1..."
setAnchorPeer 1
echo "Setting anchor peer for org2..."
setAnchorPeer 2
echo "Канал успешно создан!"

