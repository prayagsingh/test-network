set -a
[ -f .env ] && . .env
set +a

CHANNEL_NAME="$1"
CC_SRC_LANGUAGE="$2"
VERSION="$3"
DELAY="$4"
MAX_RETRY="$5"
VERBOSE="$6"
: ${CHANNEL_NAME:="mychannel"}
: ${CC_SRC_LANGUAGE:="golang"}
: ${VERSION:="1"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}
CC_SRC_LANGUAGE=`echo "$CC_SRC_LANGUAGE" | tr [:upper:] [:lower:]`

FABRIC_CFG_PATH=$PWD/../config/
echo "####### Inside deployCC and value of FABRIC_CFG_PATH is: $FABRIC_CFG_PATH"

if [ "$CC_SRC_LANGUAGE" = "go" -o "$CC_SRC_LANGUAGE" = "golang" ] ; then
	CC_RUNTIME_LANGUAGE=golang
	CC_SRC_PATH=$CC_SRC_PATH

	echo Vendoring Go dependencies ...
	pushd $CC_SRC_PATH
	GO111MODULE=on go mod vendor
  GO111MODULE=on go build
	popd
	echo Finished vendoring Go dependencies

elif [ "$CC_SRC_LANGUAGE" = "javascript" ]; then
	CC_RUNTIME_LANGUAGE=node # chaincode runtime language is node.js
	CC_SRC_PATH=$CC_SRC_PATH #"../chaincode/fabcar/javascript/"

elif [ "$CC_SRC_LANGUAGE" = "java" ]; then
	CC_RUNTIME_LANGUAGE=java
	CC_SRC_PATH=$CC_SRC_PATH/build/install/fabcar #"../chaincode/fabcar/java/build/install/fabcar"

	echo Compiling Java code ...
	pushd $CC_SRC_PATH
	./gradlew installDist
	popd
	echo Finished compiling Java code

elif [ "$CC_SRC_LANGUAGE" = "typescript" ]; then
	CC_RUNTIME_LANGUAGE=node # chaincode runtime language is node.js
	CC_SRC_PATH= $CC_SRC_PATH #"../chaincode/fabcar/typescript/"

	echo Compiling TypeScript code into JavaScript ...
	pushd $CC_SRC_PATH
	npm install
	npm run build
	popd
	echo Finished compiling TypeScript code into JavaScript

else
	echo The chaincode language ${CC_SRC_LANGUAGE} is not supported by this script
	echo Supported chaincode languages are: go, java, javascript, and typescript
	exit 1
fi

# import utils
. scripts/envVar.sh


packageChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  changeOrg $ORG 
  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${VERSION} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode packaging on peer0.$ORG_NAME has failed"
  echo "===================== Chaincode is packaged on peer0.$ORG_NAME ===================== "
  echo
}

# installChaincode PEER ORG
installChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  changeOrg $ORG
  set -x
  peer lifecycle chaincode install ${CC_NAME}.tar.gz >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on peer0.$ORG_NAME has failed"
  echo "===================== Chaincode is installed on peer0.$ORG_NAME ===================== "
  echo
}

# queryInstalled PEER ORG
queryInstalled() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  changeOrg $ORG
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  res=$?
  set +x
  cat log.txt
	PACKAGE_ID=$(sed -n "/${CC_NAME}_${VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
  verifyResult $res "Query installed on peer0.$ORG_NAME has failed"
  echo PackageID is ${PACKAGE_ID}
  echo "===================== Query installed successful on peer0.$ORG_NAME on channel ===================== "
  echo
}

# approveForMyOrg VERSION PEER ORG
approveForMyOrg() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  changeOrg $ORG
  echo
  echo "###### Approving for Org: $ORG"
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ] ; then
    set -x
    peer lifecycle chaincode approveformyorg -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${VERSION} --waitForEvent >&log.txt
    set +x
  else
    set -x
    peer lifecycle chaincode approveformyorg -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 --ordererTLSHostnameOverride orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${VERSION} --init-required --package-id ${PACKAGE_ID} --sequence ${VERSION} >&log.txt
    set +x
  fi
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer0.${ORG_NAME} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition approved on peer0.${ORG_NAME} on channel '$CHANNEL_NAME' ===================== "
  echo
}

# checkCommitReadiness VERSION PEER ORG
checkCommitReadiness() {
  PEER=$1
  ORG=$2
  shift 2
  changeOrg $ORG
  setGlobals $PEER $ORG
  
  echo "===================== Checking the commit readiness of the chaincode definition on peer${PEER}.$ORG_NAME on channel '$CHANNEL_NAME'... ===================== "
  echo ""
  local rc=1
	local COUNTER=1

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to check the commit readiness of the chaincode definition on peer$PEER.$ORG_NAME secs"
    set -x
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name $CC_NAME --version ${VERSION} --sequence ${VERSION} --output json --init-required >&log.txt
    res=$?
    set +x
		#test $res -eq 0 || continue
    let rc=0
    for var in "$@"
    do
      grep "$var" log.txt &>/dev/null || let rc=1
    done
		COUNTER=$(expr $COUNTER + 1)
	done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Checking the commit readiness of the chaincode definition successful on peer${PEER}.$ORG_NAME on channel '$CHANNEL_NAME' ===================== "
  else
    echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Check commit readiness result on peer0.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
    echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
    echo
    exit 1
  fi
}

# commitChaincodeDefinition VERSION PEER ORG (PEER ORG)...
commitChaincodeDefinition() {
  # 1 2 Both orgs 
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ] ; then
    set -x
    peer lifecycle chaincode commit -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 --channelID $CHANNEL_NAME --name $CC_NAME $PEER_CONN_PARMS --version ${VERSION} --sequence ${VERSION} --init-required >&log.txt
    res=$?
    set +x
  else
    set -x
    peer lifecycle chaincode commit -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 --ordererTLSHostnameOverride orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name $CC_NAME $PEER_CONN_PARMS --version ${VERSION} --sequence ${VERSION} --init-required >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition committed on channel '$CHANNEL_NAME' ===================== "
  echo
}

# queryCommitted ORG
queryCommitted() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  changeOrg $ORG
  EXPECTED_RESULT="Version: ${VERSION}, Sequence: ${VERSION}, Endorsement Plugin: escc, Validation Plugin: vscc"
  echo "===================== Querying chaincode definition on peer0.$ORG_NAME on channel '$CHANNEL_NAME'... ===================== "
	local rc=1
	local COUNTER=1
	# continue to poll
  # we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to Query committed status on peer0.$ORG_NAME, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name $CC_NAME >&log.txt
    res=$?
    set +x
		test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: [0-9], Sequence: [0-9], Endorsement Plugin: escc, Validation Plugin: vscc')
    test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
		COUNTER=$(expr $COUNTER + 1)
	done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Query chaincode definition successful on peer$PEER.$ORG_NAME on channel '$CHANNEL_NAME' ===================== "
		echo
  else
    echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query chaincode definition result on peer0.$ORG_NAME is INVALID !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

chaincodeInvokeInit() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "
  echo 
  echo "#### Inside chaincodeInvokeInit and value of PEER_CONN_PARMS is: $PEER_CONN_PARMS"
  echo 
  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer chaincode invoke -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 -C $CHANNEL_NAME -n $CC_NAME $PEER_CONN_PARMS --isInit -c '{"function":"initLedger","Args":[]}' >&log.txt
    res=$?
    set +x
  else
    set -x
    peer chaincode invoke -o orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION:7050 --ordererTLSHostnameOverride orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME $PEER_CONN_PARMS --isInit -c '{"function":"initLedger","Args":[]}' >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  echo "===================== Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME' ===================== "
  echo
}

chaincodeQuery() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  changeOrg $ORG
  echo "===================== Querying on peer$PEER.$ORG_NAME on channel '$CHANNEL_NAME'... ===================== "
	local rc=1
	local COUNTER=1
	# continue to poll
  # we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to Query peer0.org${ORG} ...$(($(date +%s) - starttime)) secs"
    set -x
    peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{"Args":["queryAllCars"]}' >&log.txt
    res=$?
    set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Query successful on peer$PEER.$ORG_NAME on channel '$CHANNEL_NAME' ===================== "
		echo
  else
    echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query result on peer$PEER.$ORG_NAME is INVALID !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

## at first we package the chaincode
packageChaincode 0 1

## Install chaincode on peer0.org1 and peer0.org2
echo "Installing chaincode on peer0.${DOMAIN_OF_ORGANIZATION}..."
installChaincode 0 1
echo "Installing chaincode on peer1.${DOMAIN_OF_ORGANIZATION}..."
installChaincode 1 1

if [ $NETWORK_TYPE == "multi" ]; then
  echo "Install chaincode on peer0.${DOMAIN_OF_ORGANIZATION2}..."
  installChaincode 0 2
  echo "Install chaincode on peer1.${DOMAIN_OF_ORGANIZATION2}..."
  installChaincode 1 2
fi
## query whether the chaincode is installed
## Install chaincode on peer0.org1 and peer0.org2
echo "Quering chaincode on peer0.${DOMAIN_OF_ORGANIZATION}..."
 queryInstalled 0 1
echo "Quering chaincode on peer1.${DOMAIN_OF_ORGANIZATION}..."
queryInstalled 1 1

if [ $NETWORK_TYPE == "multi" ]; then
  echo "Quering chaincode on peer0.${DOMAIN_OF_ORGANIZATION2}..."
  queryInstalled 0 2
  echo "Quering chaincode on peer1.${DOMAIN_OF_ORGANIZATION2}..."
  queryInstalled 1 2
fi

## approve the definition for org1
approveForMyOrg 0 1
## check whether the chaincode definition is ready to be committed
## expect org1 to have approved and org2 not to
checkCommitReadiness 0 1 "\"${ORGANIZATION1_NAME}MSP\": true" "\"${ORGANIZATION2_NAME}MSP\": false"
checkCommitReadiness 0 2 "\"${ORGANIZATION1_NAME}MSP\": true" "\"${ORGANIZATION2_NAME}MSP\": false"

## now approve also for org2
approveForMyOrg 0 2

## check whether the chaincode definition is ready to be committed
## expect them both to have approved
checkCommitReadiness 0 1 "\"${ORGANIZATION1_NAME}MSP\": true" "\"${ORGANIZATION2_NAME}MSP\": true"
checkCommitReadiness 0 2 "\"${ORGANIZATION1_NAME}MSP\": true" "\"${ORGANIZATION2_NAME}MSP\": true"

## now that we know for sure both orgs have approved, commit the definition
commitChaincodeDefinition 0 1 0 2

## query on both orgs to see that the definition committed successfully
queryCommitted 0 1
queryCommitted 1 1
queryCommitted 0 2
queryCommitted 1 2

## Invoke the chaincode
chaincodeInvokeInit 0 1 0 2

sleep 10

# Query chaincode on peer0.org1
echo "Querying chaincode ..."
chaincodeQuery 0 1
chaincodeQuery 1 1
chaincodeQuery 0 2
chaincodeQuery 1 2

exit 0
