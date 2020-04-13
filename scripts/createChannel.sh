#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build your test network (TYFN) end-to-end test"
echo

CHANNEL_NAME="$1"
DELAY="$2"
MAX_RETRY="$3"
VERBOSE="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

# Reading custom env from .env files
set -a
[ -f .env ] && . .env
set +a

echo "### Value of CHANNEL_NAME is: $CHANNEL_NAME"
echo "### Value of DELAY is: $DELAY"
echo "### Value of MAX_RETRY is: $MAX_RETRY"
echo "### Value of VERBOSE is: $VERBOSE"
echo "### Value of ORGANIZATION1_NAME is: $ORGANIZATION1_NAME"
echo "### Value of ORGANIZATION2_NAME is: $ORGANIZATION2_NAME"
echo "### Value of DOMAIN_OF_ORDERER_ORGANIZATION is: $DOMAIN_OF_ORDERER_ORGANIZATION"

# import utils
. scripts/envVar.sh

echo "### Value of ORGANIZATION1_NAME after import is: $ORGANIZATION1_NAME"
echo "### Value of ORGANIZATION2_NAME after import is: $ORGANIZATION2_NAME"

if [ ! -d "channel-artifacts" ]; then
	mkdir channel-artifacts
	chmod 755 -R channel-artifacts
fi

createChannelTx() {

	set -x
	configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate channel configuration transaction..."
		exit 1
	fi
	echo

}

createAncorPeerTx() {
	echo "### Value of ORGANIZATION1_NAME is: $ORGANIZATION1_NAME"
	echo "### Value of ORGANIZATION2_NAME is: $ORGANIZATION2_NAME"

	for orgmsp in $ORGANIZATION1_NAME $ORGANIZATION2_NAME; do

	echo "#######    Generating anchor peer update for ${orgmsp}  ##########"
	set -x
	configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/${orgmsp}MSPanchors.tx -channelID $CHANNEL_NAME -asOrg ${orgmsp}
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate anchor peer update for ${orgmsp}..."
		exit 1
	fi
	echo
	done
}

createChannel() {
	setGlobals 0 1

	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
        set -x
				peer channel create -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block >&log.txt
				res=$?
        set +x
		else
				set -x
				peer channel create -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
				res=$?
				set +x
		fi
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo
	echo "===================== Channel '$CHANNEL_NAME' created ===================== "
	echo
}


# queryCommitted ORG
joinChannel() {
	for org in 1 2; do
		for peer in 0 1; do
			joinChannelRetry $peer $org	
		done
	done		
}

updateAnchorPeers() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  changeOrg $ORG

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer channel update -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION --ordererTLSHostnameOverride orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
    res=$?
    set +x
  else
    set -x
    peer channel update -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 --ordererTLSHostnameOverride orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Anchor peer update failed"
  echo "===================== Anchor peers updated for org: '$ORG' on channel '$CHANNEL_NAME' ===================== "
  sleep $DELAY
  echo
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

FABRIC_CFG_PATH=${PWD}
echo "####### value of FABRIC_CFG_PATH when creating geneseis block is: $FABRIC_CFG_PATH"
## Create channeltx
echo "### Generating channel configuration transaction '${CHANNEL_NAME}.tx' ###"
createChannelTx

## Create anchorpeertx
echo "### Generating channel configuration transaction '${CHANNEL_NAME}.tx' ###"
createAncorPeerTx

FABRIC_CFG_PATH=$PWD/../config/
echo "####### value of FABRIC_CFG_PATH when creating channel: $FABRIC_CFG_PATH"
## Create channel
echo "Creating channel "$CHANNEL_NAME
createChannel

## Join all the peers to the channel
echo "Join Org1 peer0 to the channel..."
joinChannel 
#echo "Join Org2 peers to the channel..."
#joinChannel 0 2

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
updateAnchorPeers 0 1
echo "Updating anchor peers for org2..."
updateAnchorPeers 0 2

echo
echo "========= Channel successfully joined =========== "
echo

exit 0
