# aws-clientvpn-helper
A BASH script to help quickly setup AWS Client VPN for Mutal Autentication

## Overview
This is a script created to capture all the steps listed by AWS in their Administrator guide for [Getting Started](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html) and [Mutal Authentication](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/authentication-authrization.html#mutual), but in a more interactive and scalable proceedure.

Once the AWS Client VPN has been created, SSM Parameter Store is then used to distribute the Client Certificate and Key.  The helper script will check if a VPN with the name specified in the variables configuration exists, and if so will download them.

### Scope
* All the steps listed within the AWS Administrator Guide.
* Uploading the Client Certificate and Keys to AWS SSM.
* Detect and use a VPN if it has already been configured.

### Software
The following software is required to get the AWS ClientVPN up and running.

* AWS Command Line Interface
* OpenVPN Client
* OpenVPN Easy-RSA3 (Automatic)

## Installation

Once you have cloned this Git repository, either update the variable.cfg or create a symlink in your home directory.

Example:
```shell
cd ~/
ln -s ~/Source/GitHub/johnbrandborg/aws-clientvpn-helper
```

## Usage

Simply run the script below, and follow the prompts.  This will create the AWS Client VPN and generate the keys necessary.

```shell
setup.sh
```

A file called 'client-config.ovpn' is created in the working directory.  If you have installed 'openvpn' with HomeBrew on Mac OSX simple run the following to create a VPN:

```shell
openvpn client-config.ovpn
```


## To Do
- [ ] Include the creation of a Security Group rather than using the VPN default
- [ ] Create a 'teardown' script to help clean up the VPN Configuration