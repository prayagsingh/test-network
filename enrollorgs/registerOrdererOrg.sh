#set -ev
#!/bin/sh


NAME_OF_ORD_ORG=$1
ORDERER_COMPANY_DOMAIN=$2
ORD_ORG_CA_PORT=$3 

echo
echo "Enroll the ORDERER ORG CA admin"
echo
mkdir -p crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN

export FABRIC_CA_CLIENT_HOME=${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN
export TLS_CERT_FILE=${PWD}/crypto-config/fabric-ca/$ORDERER_COMPANY_DOMAIN/tls-cert.pem
export ORD_CA_URL=ca.$ORDERER_COMPANY_DOMAIN:$ORD_ORG_CA_PORT

set -x
fabric-ca-client enroll -u https://admin:adminpw@$ORD_CA_URL --caname ca.$ORDERER_COMPANY_DOMAIN --tls.certfiles $TLS_CERT_FILE
set +x

echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.'$ORDERER_COMPANY_DOMAIN'-cert.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.'$ORDERER_COMPANY_DOMAIN'-cert.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.'$ORDERER_COMPANY_DOMAIN'-cert.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.'$ORDERER_COMPANY_DOMAIN'-cert.pem
    OrganizationalUnitIdentifier: orderer' > ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/config.yaml

for ORDERER in 1 2 3; do
  echo
  echo "Register orderer$ORDERER.$ORDERER_COMPANY_DOMAIN"
  echo
  set -x
  fabric-ca-client register --caname ca.$ORDERER_COMPANY_DOMAIN --id.name orderer$ORDERER.$ORDERER_COMPANY_DOMAIN --id.secret ordererpw --id.type orderer --tls.certfiles $TLS_CERT_FILE
  set +x
done

echo
echo "Register the orderer admin"
echo
set -x
fabric-ca-client register --caname ca.$ORDERER_COMPANY_DOMAIN --id.name Admin.$ORDERER_COMPANY_DOMAIN --id.secret ordererAdminpw --id.type admin --tls.certfiles $TLS_CERT_FILE
set +x

mkdir -p crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers
#mkdir -p crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/$ORDERER_COMPANY_DOMAIN
mkdir -p ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/tlscacerts
mkdir -p crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/users

for ORDERER in 1 2 3; do
  mkdir -p crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN

  echo
  echo "## Generate the orderer$ORDERER.$ORDERER_COMPANY_DOMAIN msp"
  echo
  set -x
  fabric-ca-client enroll -u https://orderer$ORDERER.$ORDERER_COMPANY_DOMAIN:ordererpw@$ORD_CA_URL --caname ca.$ORDERER_COMPANY_DOMAIN -M ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/msp --csr.hosts orderer$ORDERER.$ORDERER_COMPANY_DOMAIN --csr.hosts localhost --tls.certfiles $TLS_CERT_FILE
  set +x

  cp ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/config.yaml ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/msp/config.yaml

  echo
  echo "## Generate orderer$ORDERER.$ORDERER_COMPANY_DOMAIN tls certificates"
  echo
  set -x
  fabric-ca-client enroll -u https://orderer$ORDERER.$ORDERER_COMPANY_DOMAIN:ordererpw@$ORD_CA_URL --caname ca.$ORDERER_COMPANY_DOMAIN -M ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls --enrollment.profile tls --csr.hosts orderer$ORDERER.$ORDERER_COMPANY_DOMAIN --csr.hosts localhost --tls.certfiles $TLS_CERT_FILE
  set +x

  cp ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/tlscacerts/* ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/ca.crt
  cp ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/signcerts/* ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/server.crt
  cp ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/keystore/* ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/server.key

  mkdir ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/msp/tlscacerts
  cp ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/tlscacerts/* ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/msp/tlscacerts/tlsca.$ORDERER_COMPANY_DOMAIN-cert.pem

  # changin name of msp/cacerts
  mv ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/msp/cacerts/*.pem ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/msp/cacerts/ca.${ORDERER_COMPANY_DOMAIN}-cert.pem

  # removing redundant directories
  rm -rf ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/tls/{cacerts,tlscacerts,signcerts,keystore,user}

  # creating admincerts directory because NodeOU isn't working. It is temporary solution
  #mkdir ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer$ORDERER.$ORDERER_COMPANY_DOMAIN/msp/admincerts

done

# Copying tls-cert from orderer1/msp to orderer-org/msp
cp ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/orderers/orderer1.$ORDERER_COMPANY_DOMAIN/tls/ca.crt ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/tlscacerts/tlsca.$ORDERER_COMPANY_DOMAIN-cert.pem

# changing cacerts name to decent one
mv ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/cacerts/*.pem ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/cacerts/ca.${ORDERER_COMPANY_DOMAIN}-cert.pem 

mkdir -p crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/users/Admin.$ORDERER_COMPANY_DOMAIN

# creating admincerts <-- temporary solution
#mkdir ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/admincerts

echo
echo "## Generate the admin msp"
echo
set -x
fabric-ca-client enroll -u https://Admin.$ORDERER_COMPANY_DOMAIN:ordererAdminpw@$ORD_CA_URL --caname ca.$ORDERER_COMPANY_DOMAIN -M ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/users/Admin.$ORDERER_COMPANY_DOMAIN/msp --tls.certfiles $TLS_CERT_FILE
set +x

cp ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/msp/config.yaml ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/users/Admin.$ORDERER_COMPANY_DOMAIN/msp/config.yaml
mv ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/users/Admin.$ORDERER_COMPANY_DOMAIN/msp/cacerts/*.pem ${PWD}/crypto-config/ordererOrganizations/$ORDERER_COMPANY_DOMAIN/users/Admin.$ORDERER_COMPANY_DOMAIN/msp/cacerts/ca.${ORDERER_COMPANY_DOMAIN}-cert.pem 


