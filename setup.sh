#!/bin/bash

echo -e "---------------------------- AWS Client VPN Helper ----------------------------\n"

# Load variables from Configuration file
. variables.cfg

# Check that all variables are available
REQUIRED_ARGUMENTS=("WORKDIR" "SERVERNAME" "CLIENTNAME" "VPNCIDRBLOCK" "OVPNCFGFILE")

for REQUIRED in ${REQUIRED_ARGUMENTS[@]}; do
    if [ -z $(eval echo \$$REQUIRED) ]; then
        echo -e " ERROR: Configuration is missing the argument $REQUIRED.\n \
Required variables are ${REQUIRED_ARGUMENTS[@]}."; exit 1
    fi
done

# Make sure the working directory is present and has the setup script
if [ -f "$WORKDIR/`basename "$0"`" ]; then
    cd $WORKDIR
else
    echo " ERROR: The working directory doesn't look valid. \
    Please make sure you update variables.cfg"; exit 1
fi

# Menu Functions

function select-vpc-cidr {
    echo ""
    PS3="Select a VPC to use: "
    VPCNAMES=$(aws ec2 describe-vpcs \
            --output=text \
            --query='Vpcs[].Tags[?Key==`Name`].Value')

    select option in $VPCNAMES; do
        VPCDETAILS=$(aws ec2 describe-vpcs \
                --output=text \
                --filters="Name=tag:Name,Values=$option" \
                --query='Vpcs[].[CidrBlock,VpcId]')
        VPCCIDR=$(echo $VPCDETAILS | cut -d" " -f1)
        VPCID=$(echo $VPCDETAILS | cut -d" " -f2)
        break
    done
}

function select-subnet-id {
    echo ""
    PS3="Select a Subnet to use: "
    SUBNETNAMES=$(aws ec2 describe-subnets \
            --output=text \
            --filter="Name=vpc-id,Values=$1" \
            --query='Subnets[].Tags[?Key==`Name`].Value')

    select option in $SUBNETNAMES; do
        SUBNETID=$(aws ec2 describe-subnets \
                --output=text \
                --filters="Name=tag:Name,Values=$option" \
                --query='Subnets[].SubnetId') && break
    done
}

# Operational Function

function create-keys {
    echo "Generating RSA Keys"

    # Install OpenVPN's Easy-RSA for generating keys
    if [ ! -d $WORKDIR/easy-rsa ]; then
        echo " - Downloading OpenVPN's Easy-RSA"
        curl https://github.com/OpenVPN/easy-rsa/tarball/master -Lso easy-rsa.tgz
        mkdir ./easy-rsa; tar -xf easy-rsa.tgz --strip 1 -C ./easy-rsa
        rm easy-rsa.tgz
    fi

    $EASYRSAPATH/easyrsa init-pki
    $EASYRSAPATH/easyrsa build-ca nopass
    $EASYRSAPATH/easyrsa build-server-full $SERVERNAME nopass
    $EASYRSAPATH/easyrsa build-client-full $CLIENTNAME nopass
}

function collect-acm-arns {
    QUERY="'CertificateSummaryList[?DomainName==\`$SERVERNAME\`].CertificateArn'"
    SERVERCERTARN=$(eval aws acm list-certificates \
                --output=text \
                --query=$QUERY)

    QUERY="'CertificateSummaryList[?DomainName==\`$CLIENTNAME\`].CertificateArn'"
    CLIENTCERTARN=$(eval aws acm list-certificates \
                --output=text \
                --query=$QUERY)
}

function acm-import-keys {
    echo "Importing RSA Keys into AWS ACM and SSM Parameter Store"

    collect-acm-arns

    if [ -n "$SERVERCERTARN" ] && [ -n "$CLIENTCERTARN" ]; then
        echo " - Certicates already exists in AWS ACM"
    else
        if [ ! -e "./pki/issued/$SERVERNAME.crt" ]; then
            create-keys
        fi

        echo " - Importing Certificates & Keys"

        aws acm import-certificate \
            --certificate=file://./pki/issued/$SERVERNAME.crt \
            --private-key=file://./pki/private/$SERVERNAME.key \
            --certificate-chain=file://./pki/ca.crt > /dev/null

        aws acm import-certificate \
            --certificate=file://./pki/issued/$CLIENTNAME.crt \
            --private-key=file://./pki/private/$CLIENTNAME.key \
            --certificate-chain=file://./pki/ca.crt > /dev/null

        ssm-put-keys
    fi
}

function ssm-put-keys {
    echo "Loading Keys into SSM Parameter Store"

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
}

function create-client-vpn {
    echo "Creating Client VPN in AWS"

    # Make sure ACM ARNs are present and known
    acm-import-keys
    collect-acm-arns

    # Gather Information about where to create the VPN
    select-vpc-cidr
    select-subnet-id $VPCID

    echo -e "\nCreating VPN now into the VPC and Subnet Selected\n"

    aws logs create-log-group --log-group-name="/aws/clientvpn" 2>/dev/null
    aws logs create-log-stream \
        --log-group-name="/aws/clientvpn" \
        --log-stream-name="$SERVERNAME" 2>/dev/null

    aws ec2 create-client-vpn-endpoint \
        --client-cidr-block="$VPNCIDRBLOCK" \
        --server-certificate-arn="$SERVERCERTARN" \
        --authentication-options="Type=certificate-authentication, \
            MutualAuthentication={ClientRootCertificateChainArn=$CLIENTCERTARN}" \
        --connection-log-options="Enabled=true,CloudwatchLogGroup=/aws/clientvpn, \
            CloudwatchLogStream=$SERVERNAME" \
        --tag-specifications="ResourceType=client-vpn-endpoint, \
            Tags=[{Key=Name,Value=$SERVERNAME}]"

    ENDPOINTID=$(aws ec2 describe-client-vpn-endpoints \
        --output=text \
        --filters="Name=tag:Name,Values=$SERVERNAME" \
        --query='ClientVpnEndpoints[].ClientVpnEndpointId')

    aws ec2 associate-client-vpn-target-network \
        --client-vpn-endpoint-id="$ENDPOINTID" \
        --subnet-id="$SUBNETID"

    aws ec2 authorize-client-vpn-ingress \
        --client-vpn-endpoint-id="$ENDPOINTID" \
        --target-network-cidr="$VPCCIDR" \
        --authorize-all-groups
    
    echo -e "\nAWS Client VPN setup process complete"
}

function create-client-config {
    echo "Creating the OpenVPN Client Configuration file"

    if [ -a "$OVPNCFGFILE" ]; then
        echo " - Previous Configuration file found.  Skipping."
    else
        : ${ENDPOINTID:=$(aws ec2 describe-client-vpn-endpoints \
                --output=text \
                --filters="Name=tag:Name,Values=$SERVERNAME"\
                --query='ClientVpnEndpoints[].ClientVpnEndpointId')}

        if [ -n "$ENDPOINTID" ]; then
            aws ec2 export-client-vpn-client-configuration \
                --client-vpn-endpoint-id $ENDPOINTID \
                --output text > $OVPNCFGFILE
        
            echo "cert $WORKDIR/pki/issued/$CLIENTNAME.crt" >> $OVPNCFGFILE
            echo "key $WORKDIR/pki/private/$CLIENTNAME.key" >> $OVPNCFGFILE
        else
            echo " ERROR: No Client VPN Endpoint could be found."; exit 1
        fi
    
    fi
}

function check-existing-vpn {
    echo "Checking to see if a VPN for "$CLIENTNAME" already exists"

    CURRENTENDPOINT=$(aws ec2 describe-client-vpn-endpoints \
                    --filter=Name=tag:Name,Values=$SERVERNAME \
                    --query='ClientVpnEndpoints[].Tags[?Key==`Name`].Value' \
                    --output=text 2>&1)

    if [ "$CURRENTENDPOINT" == "$SERVERNAME" ]; then
        echo " - VPN Exists.  Downloading Certificate now."

        if [ ! -e "./pki/issued/$CLIENTNAME.crt" ]; then
            mkdir -p ./pki/issued
            aws ssm get-parameter \
                --name="/clientvpn/$CLIENTNAME.crt" \
                --with-decryption \
                --query="Parameter.Value" > ./pki/issued/$CLIENTNAME.crt
        fi

        if [ ! -e "./pki/private/$CLIENTNAME.key" ]; then
            mkdir -p $WORKDIR/pki/private

            aws ssm get-parameter \
                --name="/clientvpn/$CLIENTNAME.key" \
                --with-decryption \
                --query="Parameter.Value" > ./pki/private/$CLIENTNAME.key
        fi
    elif [ "$CURRENTENDPOINT" == "" ]; then
        read -p "Client VPN doesn't exist.  Do you want one created? [y/n] " createopt

        if [ "$createopt" == "y" ] || [ "$createopt" == "yes" ]; then
            create-client-vpn
        else
            echo "Exiting"; exit
        fi
    else
        echo $CURRENTENDPOINT; exit
    fi
}

# Main Execution

check-existing-vpn
create-client-config

echo -e "\nPlease wait a several minutes for the VPN Association to complete before using the VPN"