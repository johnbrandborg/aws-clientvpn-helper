#!/bin/bash

echo -e "---------------------------- AWS Client VPN Helper ----------------------------\n"

# Load variables from Configuration file
. variables.cfg

# Check that all variables are available
REQUIRED_ARGUMENTS=("WORKDIR" "SERVERNAME" "CLIENTNAME")

for REQUIRED in ${REQUIRED_ARGUMENTS[@]}; do
    if [ -z $(eval echo \$$REQUIRED) ]; then
        echo -e " ERROR: Configuration is missing the argument $REQUIRED.\n \
Required variables are ${REQUIRED_ARGUMENTS[@]}."; exit 1
    fi
done

# Make sure the working directory has correct
if [ -f "$WORKDIR/`basename "$0"`"  ]; then
    cd $WORKDIR
else
    echo " ERROR: The working directory doesn't look valid. \
    Please make sure you update variables.cfg"; exit 1
fi

# Operational Function

function remove-resources {
    echo -e "Removing all AWS ClientVPN resources and the OpenVPN Configuration file\n"

    # Remove ClientVPN

    ENDPOINTID=$(aws ec2 describe-client-vpn-endpoints \
        --output=text \
        --filters="Name=tag:Name,Values=$SERVERNAME" \
        --query='ClientVpnEndpoints[].ClientVpnEndpointId')

    NETWORKASSOCID=$(aws ec2 describe-client-vpn-target-networks \
        --output=text \
        --client-vpn-endpoint-id="$ENDPOINTID" \
        --query='ClientVpnTargetNetworks[].AssociationId')

    if [ -n "$ENDPOINTID" ]; then
        aws ec2 disassociate-client-vpn-target-network \
            --client-vpn-endpoint-id="$ENDPOINTID" \
            --association-id="$NETWORKASSOCID"

        aws ec2 delete-client-vpn-endpoint \
            --client-vpn-endpoint-id="$ENDPOINTID"
    fi

    # Remove SSM Parameters

    aws ssm delete-parameter --name="/clientvpn/$CLIENTNAME.crt"
    aws ssm delete-parameter --name="/clientvpn/$CLIENTNAME.key"

    # Remove ACM Certificates

    QUERY="'CertificateSummaryList[?DomainName==\`$SERVERNAME\`].CertificateArn'"
    SERVERCERTARN=$(eval aws acm list-certificates \
                --output=text \
                --query=$QUERY)

    if [ -n "$SERVERCERTARN" ]; then
        aws acm delete-certificate --certificate-arn=$SERVERCERTARN
    fi

    QUERY="'CertificateSummaryList[?DomainName==\`$CLIENTNAME\`].CertificateArn'"
    CLIENTCERTARN=$(eval aws acm list-certificates \
                --output=text \
                --query=$QUERY)

    if [ -n "$CLIENTCERTARN" ]; then
        aws acm delete-certificate --certificate-arn=$CLIENTCERTARN
    fi

    echo -e "\nProceedure completed."
}

# Main Execution

read -p "Do you want to remove the Client VPN? [y/n] " createopt

if [ "$createopt" == "y" ] || [ "$createopt" == "yes" ]; then
    remove-resources
else
    echo "Exiting"; exit
fi


