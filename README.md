:exclamation: This repository has been archived. I recommend using the offical client instead.
https://aws.amazon.com/vpn/client-vpn-download/

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
The following software is required to get the AWS ClientVPN setup, and connectivity established.

* AWS Command Line Interface (Version >= 1.16.175)
* OpenVPN Easy-RSA3 (Downloaded Automatically)
* OpenVPN Compatible Client

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
./setup.sh
```

By default a file called 'client-config.ovpn' is created in the working directory. If you have installed the 'openvpn' commandline tool, simple run the following to create a VPN:

```shell
sudo openvpn --config client-config.ovpn
```

The alternative is to use the following scripts to start and stop OpenVPN in the background.  Logs from the Daemon will be written out to 'openvpn.log' file.

```shell
./start.sh

---------------------------- AWS Client VPN Helper ----------------------------


Starting OpenVPN as a daemon task
Password: *******

./stop.sh

---------------------------- AWS Client VPN Helper ----------------------------


Stopping all OpenVPN tasks found running
```

To remove the ClientVPN resources from AWS, (This includes Certificates & Keys in SSM Parameters, and Certificate Manager), run the teardown script.  Locally generated or stored certificates & keys, or software downloaded is not removed.  If you need to recreate the VPN, simply run the setup again.

```shell
./teardown.sh
```

Finally if you want to clean up the local Certificates & Keys, Config, Logs, and Downloaded Binaries:

```shell
./cleanup.sh
```

## To Do
- [ ] Include the creation of a Security Group rather than using the VPC default
- [X] Create a 'teardown' script to help clean up the VPN Configuration
