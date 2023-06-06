#!/bin/bash 
set -ex


source variables.cfg

./easy-rsa/easyrsa3/easyrsa renew server $SERVERNAME nopass

aws acm import-certificate \
    --certificate=fileb://./pki/issued/$SERVERNAME.crt \
    --private-key=fileb://./pki/private/$SERVERNAME.key \
    --certificate-chain=fileb://./pki/ca.crt

aws ssm put-parameter \
    --name="/clientvpn/$CLIENTNAME.crt" \
    --description="Compressed Client Certificate for AWS Client VPN" \
    --value=file://./pki/issued/$CLIENTNAME.crt \
    --type="SecureString" \
    --tier="Advanced" \
    --overwrite > /dev/null

aws ssm put-parameter \
    --name="/clientvpn/$CLIENTNAME.key" \
    --description="Compressed Client Key for AWS Client VPN" \
    --value=file://./pki/private/$CLIENTNAME.key \
    --type="SecureString" \
    --tier="Advanced" \
    --overwrite > /dev/null

echo "New server certificate generated."

ENDPOINTID=$(aws ec2 describe-client-vpn-endpoints \
    --output=text \
    --filters="Name=tag:Name,Values=$SERVERNAME" \
    --query='ClientVpnEndpoints[].ClientVpnEndpointId')

QUERY="'CertificateSummaryList[?DomainName==\`$SERVERNAME\`].CertificateArn'"
SERVERCERTARN=$(eval aws acm list-certificates \
            --output=text \
            --query=$QUERY)

aws ec2 modify-client-vpn-endpoint
    --client-vpn-endpoint-id="$ENDPOINTID"
    --server-certificate-arn="$SERVERCERTARN"

echo "Updated VPN to use new server certificate."
