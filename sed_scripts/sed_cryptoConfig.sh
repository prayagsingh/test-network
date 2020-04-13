#set -ev
#!/bin/sh

# true multi Ord ord.com Org1 org1.com Org2 org2.com  
# true single Ord ord.com Org1 org1.com
# false single Org1 org1.com
# false multi Org1 org1.com Org2 org2.com

set -a
[ -f .env ] && . .env
set +a

ORDERER_FLAG=$1
NETWORK_TYPE=$2
if [ $ORDERER_FLAG == "true" ];then
    NAME_OF_ORDERER_ORGANIZATION=$3
    DOMAIN_OF_ORDERER_ORGANIZATION=$4

    ORGANIZATION1_NAME=$5
    DOMAIN_OF_ORGANIZATION=$6
    export ORGANIZATION_NAME_LOWERCASE=`echo "$ORGANIZATION1_NAME" | tr '[:upper:]' '[:lower:]'`

    if [ $NETWORK_TYPE == "multi" ];then
        ORGANIZATION2_NAME=$7
        DOMAIN_OF_ORGANIZATION2=$8  
        export ORGANIZATION2_NAME_LOWERCASE=`echo "$ORGANIZATION2_NAME" | tr '[:upper:]' '[:lower:]'`  
    fi
else    
    ORGANIZATION1_NAME=$3
    DOMAIN_OF_ORGANIZATION=$4
    export ORGANIZATION_NAME_LOWERCASE=`echo "$ORGANIZATION1_NAME" | tr '[:upper:]' '[:lower:]'`

    if [ $NETWORK_TYPE == "multi" ];then
        ORGANIZATION2_NAME=$6
        DOMAIN_OF_ORGANIZATION2=$7 
        export ORGANIZATION2_NAME_LOWERCASE=`echo "$ORGANIZATION2_NAME" | tr '[:upper:]' '[:lower:]'`  
    fi

fi
function createCryptoConfigfile() {
    echo ""
    echo " #########################################################################"
    echo " ########### Creating crypto-config.yaml file from templates #############"
    echo " #########################################################################"
    echo ""

    # Orderer Org
    if [ $ORDERER_FLAG == "true" ];then
        sed -e 's/orderer_organization_name/'$NAME_OF_ORDERER_ORGANIZATION'/g' \
            -e 's/orderer_organization_domain/'$DOMAIN_OF_ORDERER_ORGANIZATION'/g' templates/crypto-config-orderer_temp.yaml > ../cryptogen/crypto-config-orderer.yaml
    fi

    # Org1   
    sed -e 's/organization_name/'$ORGANIZATION1_NAME'/g' \
        -e 's/organization_domain/'$DOMAIN_OF_ORGANIZATION'/g' templates/crypto-config-org1_temp.yaml > ../cryptogen/crypto-config-$ORGANIZATION_NAME_LOWERCASE.yaml 
    
    if [ $NETWORK_TYPE == "multi" ];then
        # Org2	
        sed -e 's/organization2_name/'$ORGANIZATION2_NAME'/g' \
            -e 's/organization2_domain/'$DOMAIN_OF_ORGANIZATION2'/g' templates/crypto-config-org2_temp.yaml > ../cryptogen/crypto-config-$ORGANIZATION2_NAME_LOWERCASE.yaml
    fi
    echo " ########### finished creating crypto-config.yaml file from templates #############"
}

createCryptoConfigfile