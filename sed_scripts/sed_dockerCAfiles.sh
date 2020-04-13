#set -ev
#!/bin/sh

set -a
[ -f .env ] && . .env
set +a

NETWORK_TYPE=$1
ORDERER_FLAG=$2    
ORGANIZATION_NAME_LOWERCASE=$3
DOMAIN_OF_ORGANIZATION=$4
PORT_NUMBER=$5
    
if [ $ORDERER_FLAG == "true" ];then
    if [ $NETWORK_TYPE == "multi" ];then
        ORDERER_ORGANIZATION_NAME_LOWERCASE=$6
        DOMAIN_OF_ORDERER_ORGANIZATION=$7
        ORD_PORT_NUMBER=$8
        ORGANIZATION2_NAME_LOWERCASE=$9
        DOMAIN_OF_ORGANIZATION2=${10}
        ORG2_PORT_NUMBER=${11}
    else
        ORDERER_ORGANIZATION_NAME_LOWERCASE=$6
        DOMAIN_OF_ORDERER_ORGANIZATION=$7
        ORD_PORT_NUMBER=$8
    fi
else 
    if [ $NETWORK_TYPE == "multi" ];then
        ORGANIZATION2_NAME_LOWERCASE=$6
        DOMAIN_OF_ORGANIZATION2=$7
        ORG2_PORT_NUMBER=$8
    fi    
fi

pwd
echo ""
echo " ##############################################################"
echo " ############# Creating docker CA file for Orgs ###############"
echo " ##############################################################"
echo ""

if [ $NETWORK_TYPE == "single" ];then
    if [ $ORDERER_FLAG == "true" ];then
        echo " ########### Creating a docker-orderer-ca.yaml file from template"
        sed -e 's/organization_small_name/'$ORDERER_ORGANIZATION_NAME_LOWERCASE'/g' -e 's/organization_domain/'$DOMAIN_OF_ORDERER_ORGANIZATION'/g' -e 's/port_number/'$ORD_PORT_NUMBER'/g' templates/docker-compose-ca-template.yaml > ./docker/docker-compose-ca-orderer.yaml
    fi    
    echo " ########### Creating docker-compose-ca-org1.yaml file from template"
    sed -e 's/organization_small_name/'$ORGANIZATION_NAME_LOWERCASE'/g' -e 's/organization_domain/'$DOMAIN_OF_ORGANIZATION'/g' -e 's/port_number/'$PORT_NUMBER'/g' templates/docker-compose-ca-template.yaml > ./docker/docker-compose-ca-$ORGANIZATION_NAME_LOWERCASE.yaml
    echo ""
    echo " ########### Creating Orderer and peer files"
    ./sed_docker_files.sh $NETWORK_TYPE $DOMAIN_OF_ORDERER_ORGANIZATION $DOMAIN_OF_ORGANIZATION $ORGANIZATION1_NAME $ORDERER_FLAG
    echo ""
else
    if [ $ORDERER_FLAG == "true" ];then
        echo " ########### Creating a docker-orderer-ca.yaml file from template"
        sed -e 's/organization_small_name/'$ORDERER_ORGANIZATION_NAME_LOWERCASE'/g' -e 's/organization_domain/'$DOMAIN_OF_ORDERER_ORGANIZATION'/g' -e 's/port_number/'$ORD_PORT_NUMBER'/g' templates/docker-compose-ca-template.yaml > ./docker/docker-compose-ca-orderer.yaml
    fi
    
    echo " ########### Creating docker-compose-ca-org1.yaml file from template"
    sed -e 's/organization_small_name/'$ORGANIZATION_NAME_LOWERCASE'/g' -e 's/organization_domain/'$DOMAIN_OF_ORGANIZATION'/g' -e 's/port_number/'$PORT_NUMBER'/g' templates/docker-compose-ca-template.yaml > ./docker/docker-compose-ca-$ORGANIZATION_NAME_LOWERCASE.yaml
    echo ""

    echo "########### Creating docker-compose-ca-org2.yaml file from template"
    sed -e 's/organization_small_name/'$ORGANIZATION2_NAME_LOWERCASE'/g' -e 's/organization_domain/'$DOMAIN_OF_ORGANIZATION2'/g' -e 's/port_number/'$ORG2_PORT_NUMBER'/g' templates/docker-compose-ca-template.yaml > ./docker/docker-compose-ca-$ORGANIZATION2_NAME_LOWERCASE.yaml
    echo ""
    echo " ########### Creating Orderer and peer files"
    ./sed_scripts/sed_docker_files.sh $NETWORK_TYPE $DOMAIN_OF_ORDERER_ORGANIZATION $DOMAIN_OF_ORGANIZATION $ORGANIZATION1_NAME $ORDERER_FLAG $ORGANIZATION2_NAME $DOMAIN_OF_ORGANIZATION2
fi
