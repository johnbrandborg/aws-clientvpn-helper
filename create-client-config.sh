#!/bin/bash 
set -ex


source variables.cfg

./easy-rsa/easyrsa3/easyrsa build-client-full $CLIENTNAME nopass

aws acm import-certificate \
    --certificate=fileb://./pki/issued/$CLIENTNAME.crt \
    --private-key=fileb://./pki/private/$CLIENTNAME.key \
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

: ${ENDPOINTID:=$(aws ec2 describe-client-vpn-endpoints \
            --output=text \
            --filters="Name=tag:Name,Values=$SERVERNAME"\
            --query='ClientVpnEndpoints[].ClientVpnEndpointId')}

if [ -n "$ENDPOINTID" ]; then
    aws ec2 export-client-vpn-client-configuration \
        --client-vpn-endpoint-id $ENDPOINTID \
        --output text > $OVPNCFGFILE

    echo "cert $CLIENTNAME.crt" >> $OVPNCFGFILE
    echo "key $CLIENTNAME.key" >> $OVPNCFGFILE
else
    echo " ERROR: No Client VPN Endpoint could be found."; exit 1
fi



mkdir -p $WORKDIR/$CLIENTNAME
cp $OVPNCFGFILE $WORKDIR/$CLIENTNAME
cp pki/issued/$CLIENTNAME.crt $WORKDIR/$CLIENTNAME/
cp pki/private/$CLIENTNAME.key $WORKDIR/$CLIENTNAME/