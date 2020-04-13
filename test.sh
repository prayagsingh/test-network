#!/bin/bash

# Hello World Program in Bash Shell
set -a
[ -f .env ] && . .env
set +a

echo "Hello World!"

# import utils
. scripts/envVar.sh

parsePeerConnectionParameters() {
  # check for uneven number of peer and org parameters

  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    #setGlobals $1
    PEER="peer0.org$1" # peer0.org1
    PEERS="$PEERS $PEER" # "peer0.org1"
    echo
    echo "Value of PEER is: $PEER"
    echo "Value of PEERS is: $PEERs"
    echo
    # " --peerAddresses "
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    echo 
    echo "Value of PEER_CONN_PARAMS is: $PEER_CONN_PARMS"
    echo
    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "true" ]; then
      TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER0_ORG${1}_CA")
      PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
      echo 
      echo "Value of PEER_CONN_PARAMS is: $PEER_CONN_PARMS"
      echo
    fi
    # shift by two to get the next pair of peer/org parameters
    shift
  done
  # remove leading space for output
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
  echo 
  echo "Value of PEERS is: $PEERS"
  echo
}

for a in 1 2; do
    for b in 0 1; do
        parsePeerConnectionParameters a
    done
done       


# TEST 2
echo 
echo "##### TEST 2"
echo 

checkCommitReadiness() {
  VERSION=$1
  PEER=$2
  ORG=$3
  CHANNEL_NAME="mychannel"
  DELAY=2
  TIMEOUT=10
  shift 3
  setGlobals $PEER $ORG
  echo "===================== Checking the commit readiness of the chaincode definition on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while
    x=$(date +%s)
    y=$x-$starttime
    echo "value of xy is $y"
    test "$(($(date +%s) - starttime))" -lt "$TIMEOUT" -a $rc -ne 0
    echo "value of test is $test"
  do
    sleep $DELAY
    set -x
    echo "Attempting to check the commit readiness of the chaincode definition on peer${PEER}.org${ORG} ...$(($(date +%s) - starttime)) secs"
    #peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name mycc $PEER_CONN_PARMS --version ${VERSION} --sequence ${VERSION} --output json --init-required >&log.txt
    res=$?
    set +x
    test $res -eq 0 || continue
    let rc=0
    for var in "$@"
    do
        grep "$var" log.txt &>/dev/null || let rc=1
    done
  done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Checking the commit readiness of the chaincode definition successful on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  else
    echo "!!!!!!!!!!!!!!! Check commit readiness result on peer${PEER}.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
    echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
    echo
    exit 1
  fi
}

checkCommitReadiness 1 0 1 "\"${ORGANIZATION1_NAME}MSP\": true" "\"${ORGANIZATION1_NAME2}MSP\": false"