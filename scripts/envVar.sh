#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This is a collection of bash functions used by different scripts
set -a
[ -f .env ] && . .env
set +a

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/crypto-config/ordererOrganizations/$DOMAIN_OF_ORDERER_ORGANIZATION/orderers/orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION/msp/tlscacerts/tlsca.$DOMAIN_OF_ORDERER_ORGANIZATION-cert.pem
export PEER0_ORG1_CA=${PWD}/crypto-config/peerOrganizations/$DOMAIN_OF_ORGANIZATION/peers/peer0.$DOMAIN_OF_ORGANIZATION/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/crypto-config/peerOrganizations/$DOMAIN_OF_ORGANIZATION2/peers/peer0.$DOMAIN_OF_ORGANIZATION2/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/crypto-config/peerOrganizations/$DOMAIN_OF_ORGANIZATION/peers/peer0.$DOMAIN_OF_ORGANIZATION/tls/ca.crt

# echo 
# echo "###### Inside envVar.sh file"
# echo "### Value of NAME_OF_ORD_ORG is: $NAME_OF_ORD_ORG"
# echo "### Value of DOMAIN_OF_ORDERER_ORGANIZATION is: $DOMAIN_OF_ORDERER_ORGANIZATION"
# echo "### Value of ORGANIZATION1_NAME is: $ORGANIZATION1_NAME"
# echo "### Value of DOMAIN_OF_ORGANIZATION is: $DOMAIN_OF_ORGANIZATION"
# echo "### Value of ORGANIZATION2_NAME is: $ORGANIZATION2_NAME"
# echo "### Value of DOMAIN_OF_ORGANIZATION2 is: $DOMAIN_OF_ORGANIZATION2"
# echo "### Value of ORDERER_CA is: $ORDERER_CA"
# echo "### Value of PEER0_ORG1_CA is: $PEER0_ORG1_CA"
# echo "### Value of PEER0_ORG2_CA is: $PEER0_ORG2_CA"

# Set OrdererOrg.Admin globals
setOrdererGlobals() {
  export CORE_PEER_LOCALMSPID="${NAME_OF_ORD_ORG}MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/crypto-config/ordererOrganizations/$DOMAIN_OF_ORDERER_ORGANIZATION/orderers/orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION/msp/tlscacerts/tlsca.$DOMAIN_OF_ORDERER_ORGANIZATION-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/crypto-config/ordererOrganizations/$DOMAIN_OF_ORDERER_ORGANIZATION/users/Admin.$DOMAIN_OF_ORDERER_ORGANIZATION/msp

  echo "#### Value of CORE_PEER_LOCALMSPID is $CORE_PEER_LOCALMSPID"
  echo "#### Value of CORE_PEER_TLS_ROOTCERT_FILE is $CORE_PEER_TLS_ROOTCERT_FILE"
  echo "#### Value of CORE_PEER_MSPCONFIGPATH is $CORE_PEER_MSPCONFIGPATH"
}

# Set environment variables for the peer org
setGlobals() {
  #local USING_ORG=""
  PEER=$1
  USING_ORG=$2

  echo 
  echo "Inside setGlobals and Value of PEER is $PEER"
  echo "Inside setGlobals and Value of USING_ORG is $USING_ORG"
  echo 
  echo "Using organization ${USING_ORG}"
  if [[ $USING_ORG -eq 1 ]]; then
    export CORE_PEER_LOCALMSPID="${ORGANIZATION1_NAME}MSP"
    export CORE_PEER_MSPCONFIGPATH=${PWD}/crypto-config/peerOrganizations/$DOMAIN_OF_ORGANIZATION/users/Admin.$DOMAIN_OF_ORGANIZATION/msp
    
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    if [ $PEER -eq 0 ]; then
      export CORE_PEER_ADDRESS=peer0.${DOMAIN_OF_ORGANIZATION}:7051
    else
      export CORE_PEER_ADDRESS=peer1.${DOMAIN_OF_ORGANIZATION}:8051
    fi  

  elif [[ $USING_ORG -eq 2 ]]; then
    export CORE_PEER_LOCALMSPID="${ORGANIZATION2_NAME}MSP"
    export CORE_PEER_MSPCONFIGPATH=${PWD}/crypto-config/peerOrganizations/$DOMAIN_OF_ORGANIZATION2/users/Admin.$DOMAIN_OF_ORGANIZATION2/msp
    
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    if [ $PEER -eq 0 ]; then
      export CORE_PEER_ADDRESS=peer0.$DOMAIN_OF_ORGANIZATION2:9051
    else
      export CORE_PEER_ADDRESS=peer1.$DOMAIN_OF_ORGANIZATION2:10051
    fi  

  elif [[ $USING_ORG -eq 3 ]]; then
    export CORE_PEER_LOCALMSPID="${ORGANIZATION1_NAME}MSP"
    export CORE_PEER_MSPCONFIGPATH=${PWD}/crypto-config/peerOrganizations/$DOMAIN_OF_ORGANIZATION/users/Admin.$DOMAIN_OF_ORGANIZATION/msp

    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    if [ $PEER -eq 0 ]; then
      export CORE_PEER_ADDRESS=peer0.$DOMAIN_OF_ORGANIZATION:11051
    else
      export CORE_PEER_ADDRESS=peer1.$DOMAIN_OF_ORGANIZATION:12051
    fi

  else
    echo "================== ERROR !!! ORG Unknown =================="
  fi

  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}

# joining channel with retry --> calling this in joinChannel() function in createChannel.sh
joinChannelRetry() {
	PEER=$1
	ORG=$2
  echo
  echo "Value of PEER is $PEER"
  echo "Value of ORG is $ORG"
  echo
	setGlobals $PEER $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block >&log.txt
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	echo
	if [[ $ORG -eq 1 ]];then
		ORGNAME=$DOMAIN_OF_ORGANIZATION
	else
		ORGNAME=$DOMAIN_OF_ORGANIZATION2
	fi
	verifyResult $res "After $MAX_RETRY attempts, peer$peer.${ORGNAME} has failed to join channel '$CHANNEL_NAME' "
}

# parsePeerConnectionParameters $@
# Helper function that takes the parameters from a chaincode operation
# (e.g. invoke, query, instantiate) and checks for an even number of
# peers and associated org, then sets $PEER_CONN_PARMS and $PEERS
parsePeerConnectionParameters() {
  # check for uneven number of peer and org parameters
  if [ $(($# % 2)) -ne 0 ]; then
    exit 1
  fi

  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1 $2
    PEER="peer$1.org$2"
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "true" ]; then
      TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER$1_ORG$2_CA")
      PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    fi
    # shift by two to get the next pair of peer/org parameters
    shift
    shift
  done
  # remove leading space for output
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
  echo 
  echo "#### Indside parsePeerConnectionParams and value of PEERS is: $PEERS"
  echo "#### Indside parsePeerConnectionParams and value of PEER_CONN_PARMS is: $PEER_CONN_PARMS"
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

changeOrg(){
  ORG=$1

  if [ $ORG -eq 1 ]; then
    ORG_NAME=$DOMAIN_OF_ORGANIZATION
  elif [ $ORG -eq 2 ]; then
    ORG_NAME=$DOMAIN_OF_ORGANIZATION2
  else
    ORG_NAME=$DOMAIN_OF_ORGANIZATION3
  fi      
}