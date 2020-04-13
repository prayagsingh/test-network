#set -ev
#!/bin/sh

NETWORK_TYPE=$1
NAME_OF_ORDERER_ORGANIZATION=$2
ORGANIZATION1_NAME=$3
DOMAIN_OF_ORDERER_ORGANIZATION=$4
DOMAIN_OF_ORGANIZATION=$5
if [ $NETWORK_TYPE == "multi" ];then
    ORGANIZATION2_NAME=$6
    DOMAIN_OF_ORGANIZATION2=$7
    ORGANIZATION2_NAME_LOWERCASE=`echo "$ORGANIZATION2_NAME" | tr '[:upper:]' '[:lower:]'`
    ORG2_ANCHOR_PEER=peer0.$DOMAIN_OF_ORGANIZATION2
fi
ORGANIZATION_NAME_LOWERCASE=`echo "$ORGANIZATION_NAME" | tr '[:upper:]' '[:lower:]'`
ORG1_ANCHOR_PEER=peer0.$DOMAIN_OF_ORGANIZATION
ORDERER1_ADDRESS=orderer1.$DOMAIN_OF_ORDERER_ORGANIZATION
ORDERER2_ADDRESS=orderer2.$DOMAIN_OF_ORDERER_ORGANIZATION
ORDERER3_ADDRESS=orderer3.$DOMAIN_OF_ORDERER_ORGANIZATION

# Substitutes organizations information in the configtx template to match organizations name, domain and ip address
function createConfigtxfile() {
    echo ""
    echo " #####################################################"
    echo " ########### Creating configtx.yaml file #############"
    echo " #####################################################"
    echo ""
    if [ $NETWORK_TYPE == "multi" ];then
        sed -e 's/orderer_organization_name/'$NAME_OF_ORDERER_ORGANIZATION'/g' \
            -e 's/organization_name/'$ORGANIZATION1_NAME'/g' \
            -e 's/orderer_organization_domain/'$DOMAIN_OF_ORDERER_ORGANIZATION'/g' \
            -e 's/organization_domain/'$DOMAIN_OF_ORGANIZATION'/g' \
            -e 's/organization2_name/'$ORGANIZATION2_NAME'/g' \
            -e 's/organization2_domain/'$DOMAIN_OF_ORGANIZATION2'/g' \
            -e 's/organization_small_name/'$ORGANIZATION_NAME_LOWERCASE'/g' \
            -e 's/organization2_small_name/'$ORGANIZATION2_NAME_LOWERCASE'/g' \
            -e 's/org1_anchorpeer_address/'$ORG1_ANCHOR_PEER'/g' \
            -e 's/org2_anchorpeer_address/'$ORG2_ANCHOR_PEER'/g' \
            -e 's/orderer1_address/'$ORDERER1_ADDRESS'/g' \
            -e 's/orderer2_address/'$ORDERER2_ADDRESS'/g' \
            -e 's/orderer3_address/'$ORDERER3_ADDRESS'/g' templates/multiple/configtx_template.yaml > configtx.yaml
    else    
        sed -e 's/orderer_organization_name/'$NAME_OF_ORDERER_ORGANIZATION'/g' \
        -e 's/organization_name/'$ORGANIZATION1_NAME'/g' \
        -e 's/orderer_organization_domain/'$DOMAIN_OF_ORDERER_ORGANIZATION'/g' \
        -e 's/organization_domain/'$DOMAIN_OF_ORGANIZATION'/g' \
        -e 's/organization_small_name/'$ORGANIZATION_NAME_LOWERCASE'/g' \
        -e 's/org1_anchorpeer_address/'$ORG1_ANCHOR_PEER'/g' \
        -e 's/orderer1_address/'$ORDERER1_ADDRESS'/g' \
        -e 's/orderer2_address/'$ORDERER2_ADDRESS'/g' \
        -e 's/orderer3_address/'$ORDERER3_ADDRESS'/g' templates/single/configtx_single_org_template.yaml > configtx.yaml
    fi

    echo " ########### Finished creating configtx.yaml file #############"
}

createConfigtxfile
