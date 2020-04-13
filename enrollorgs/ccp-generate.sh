#!/bin/bash


NETWORK_TYPE=$1
ORG1_NAME=$2
ORG1_DOMAIN=$3
P0PORT=7051
P1PORT=8051
CAPORT=$4
if [ $NETWORK_TYPE == "multi" ];then
    ORG2_NAME=$5
    ORG2_DOMAIN=$6
    CAPORT2=$7
fi
PEERPEM=./crypto-config/peerOrganizations/${ORG1_DOMAIN}/tlsca/tlsca.${ORG1_DOMAIN}-cert.pem
CAPEM=./crypto-config/peerOrganizations/${ORG1_DOMAIN}/ca/ca.${ORG1_DOMAIN}-cert.pem

export ORG1_NAME_SMALL=`echo "$ORG1_NAME" | tr '[:upper:]' '[:lower:]'`
export ORG2_NAME_SMALL=`echo "$ORG2_NAME" | tr '[:upper:]' '[:lower:]'`

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`" # $1 for reading the first argument
}

function json_ccp {
    local PP=$(one_line_pem $6)
    local CP=$(one_line_pem $7)
    sed -e "s/\${ORG_NAME}/$1/" \
        -e "s/\${ORG_DOMAIN}/$2/" \
        -e "s/\${P0PORT}/$3/" \
        -e "s/\${P1PORT}/$4/" \
        -e "s/\${CAPORT}/$5/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        ./templates/ccp-template.json
}

function yaml_ccp {
    local PP=$(one_line_pem $6)
    local CP=$(one_line_pem $7)
    sed -e "s/\${ORG_NAME}/$1/" \
        -e "s/\${ORG_DOMAIN}/$2/" \
        -e "s/\${P0PORT}/$3/" \
        -e "s/\${P1PORT}/$4/" \
        -e "s/\${CAPORT}/$5/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        ./templates/ccp-template.yaml | sed -e $'s/\\\\n/\\\n        /g'
}

function multiorgs(){

    local P0PORT=9051
    local P1PORT=10051
    PEERPEM=./crypto-config/peerOrganizations/${ORG2_DOMAIN}/tlsca/tlsca.${ORG2_DOMAIN}-cert.pem
    CAPEM=./crypto-config/peerOrganizations/${ORG2_DOMAIN}/ca/ca.${ORG2_DOMAIN}-cert.pem

    echo "$(json_ccp $ORG2_NAME $ORG2_DOMAIN $P0PORT $P1PORT $CAPORT2 $PEERPEM $CAPEM)" > ./crypto-config/peerOrganizations/${ORG2_DOMAIN}/connection-${ORG2_NAME_SMALL}.json
    echo "$(yaml_ccp $ORG2_NAME $ORG2_DOMAIN $P0PORT $P1PORT $CAPORT2 $PEERPEM $CAPEM)" > ./crypto-config/peerOrganizations/${ORG2_DOMAIN}/connection-${ORG2_NAME_SMALL}.yaml

}

echo "$(json_ccp $ORG1_NAME $ORG1_DOMAIN $P0PORT $P1PORT $CAPORT $PEERPEM $CAPEM)" > ./crypto-config/peerOrganizations/${ORG1_DOMAIN}/connection-${ORG1_NAME_SMALL}.json
echo "$(yaml_ccp $ORG1_NAME $ORG1_DOMAIN $P0PORT $P1PORT $CAPORT $PEERPEM $CAPEM)" > ./crypto-config/peerOrganizations/${ORG1_DOMAIN}/connection-${ORG1_NAME_SMALL}.yaml

if [ $NETWORK_TYPE == "multi" ];then
    multiorgs
fi

