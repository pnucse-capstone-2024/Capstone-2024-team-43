#!/bin/bash

source scripts/utils.sh

CHANNEL_NAME=${1:-"public-channel"}
CC_NAME=${2}
CC_SRC_PATH=${3}
CC_SRC_LANGUAGE=${4}
CC_VERSION=${5:-"1.0"}
CC_SEQUENCE=${6:-"1"}
CC_INIT_FCN=${7:-"NA"}
CC_END_POLICY=${8:-"NA"}
CC_COLL_CONFIG=${9:-"NA"}
DELAY=${10:-"3"}
MAX_RETRY=${11:-"5"}
VERBOSE=${12:-"false"}

println "executing with the following"
println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
println "- CC_SRC_LANGUAGE: ${C_GREEN}${CC_SRC_LANGUAGE}${C_RESET}"
println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
println "- CC_END_POLICY: ${C_GREEN}${CC_END_POLICY}${C_RESET}"
println "- CC_COLL_CONFIG: ${C_GREEN}${CC_COLL_CONFIG}${C_RESET}"
println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"
println "- DELAY: ${C_GREEN}${DELAY}${C_RESET}"
println "- MAX_RETRY: ${C_GREEN}${MAX_RETRY}${C_RESET}"
println "- VERBOSE: ${C_GREEN}${VERBOSE}${C_RESET}"

INIT_REQUIRED="--init-required"
# check if the init fcn should be called
if [ "$CC_INIT_FCN" = "NA" ]; then
  INIT_REQUIRED=""
fi

if [ "$CC_END_POLICY" = "NA" ]; then
  CC_END_POLICY=""
else
  CC_END_POLICY="--signature-policy $CC_END_POLICY"
fi

if [ "$CC_COLL_CONFIG" = "NA" ]; then
  CC_COLL_CONFIG=""
else
  CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
fi

FABRIC_CFG_PATH=$PWD/../config/

# import utils
. scripts/envVar.sh
. scripts/ccutils.sh

function checkPrereqs() {
  jq --version > /dev/null 2>&1

  if [[ $? -ne 0 ]]; then
    errorln "jq command not found..."
    errorln
    errorln "Follow the instructions in the Fabric docs to install the prereqs"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/prereqs.html"
    exit 1
  fi
}

#check for prerequisites
checkPrereqs

## package the chaincode
./scripts/packageCC.sh $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION 

PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz)

infoln "Install chaincode on peer0.org1..."
installChaincode 1
infoln "Install chaincode on peer0.org2..."
installChaincode 2
infoln "Install chaincode on peer0.org3..."
installChaincode 3
infoln "Install chaincode on peer0.org4..."
installChaincode 4
infoln "Installing chaincode on peer0.org6..."
infoln "Install chaincode on peer0.org5..."
installChaincode 5
infoln "Installing chaincode on peer0.org6..."
installChaincode 6
infoln "Install chaincode on peer0.org7..."
installChaincode 7

resolveSequence

## query whether the chaincode is installed
queryInstalled 1
queryInstalled 2
queryInstalled 3
queryInstalled 4
queryInstalled 5
queryInstalled 6
queryInstalled 7

approveForMyOrg 1
approveForMyOrg 2
approveForMyOrg 3
approveForMyOrg 4
approveForMyOrg 5
#checkCommitReadiness 2 "\"Org2MSP\": true" "\"Org6MSP\": false" "\"Org7MSP\": false"
#checkCommitReadiness 6 "\"Org2MSP\": true" "\"Org6MSP\": false" "\"Org7MSP\": false"
#checkCommitReadiness 7 "\"Org2MSP\": true" "\"Org6MSP\": false" "\"Org7MSP\": false"

approveForMyOrg 6
approveForMyOrg 7

## check whether the chaincode definition is ready to be committed
## expect all organizations to have approved
#checkCommitReadiness 2 "\"Org2MSP\": true" "\"Org6MSP\": true" "\"Org7MSP\": true"
#checkCommitReadiness 6 "\"Org2MSP\": true" "\"Org6MSP\": true" "\"Org7MSP\": true"
#checkCommitReadiness 7 "\"Org2MSP\": true" "\"Org6MSP\": true" "\"Org7MSP\": true"

## now that we know for sure all orgs have approved, commit the definition
commitChaincodeDefinition 1 2 3 4 5 6 7

## query on both orgs to see that the definition committed successfully
queryCommitted 1
queryCommitted 2
queryCommitted 3
queryCommitted 4
queryCommitted 5
queryCommitted 6
queryCommitted 7

## Invoke the chaincode - this does require that the chaincode have the 'initLedger' method defined
if [ "$CC_INIT_FCN" = "NA" ]; then
  infoln "Chaincode initialization is not required"
else
  chaincodeInvokeInit 1 2 3 4 5 6 7
fi

exit 0
