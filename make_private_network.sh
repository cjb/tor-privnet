#!/bin/bash

#set -e

AUTHORITIES=3
RELAYS=15
CLIENTS=1

TOR=/path/to/tor
GENCERT=/path/to/tor-gencert

#################################################################

WD=`pwd`/work

mkdir -p $WD/authorities/
mkdir -p $WD/relays/
mkdir -p $WD/clients/

# Set up authorities

DIRSERVER_LINE=

# Make authority keys
NUM=$AUTHORITIES
while [ $NUM -gt 0 ]; do
	path=$WD/authorities/auth$NUM;
	mkdir -p $path;
	cd $path;
	let ORPORT=3000+$NUM
	let DIRPORT=4000+$NUM
	cat <<-EOF >$path/torrc.tmp
	DirServer test 127.0.0.1:1 0000000000000000000000000000000000000000
	OrPort 1
	EOF

	FP=`$TOR --quiet --list-fingerprint --DataDirectory $path -f torrc.tmp \
	| cut -f 2,3,4,5,6,7,8,9,10,11 -d " " | sed 's/ //g'`;

	rm -rf $path/torrc.tmp

	# Make a dummy password for this authority
	echo $NUM$NUM$NUM$NUM > password

	exec 5<> password
	$GENCERT --create-identity-key --passphrase-fd 5
	exec 5>&-

	mv authority_certificate authority_signing_key keys/

	V3ID=`grep fingerprint keys/authority_certificate | cut -f 2 -d " "`;
	
	DIRSERVER_LINE="DirServer authority$NUM v3ident=$V3ID orport=$ORPORT \
	no-v2 127.0.0.1:$DIRPORT $FP"$'\n'"$DIRSERVER_LINE";

	let NUM=$NUM-1
done

# Configure them

NUM=$AUTHORITIES
while [ $NUM -gt 0 ]; do

	path=$WD/authorities/auth$NUM;
	let ORPORT=3000+$NUM
	let DIRPORT=4000+$NUM

	# Make the config file
	cat <<-EOF >$path/torrc
	TestingTorNetwork 1
	DataDirectory $path
	Log notice file $path/notice.log
	Nickname authority$NUM
	SocksPort 0
	OrPort $ORPORT
	Address 127.0.0.1
	DirPort $DIRPORT
	ConnLimit 90
	AuthoritativeDirectory 1
	V3AuthoritativeDirectory 1
	ContactInfo auth$NUM@test.test
	ExitPolicy reject *:*
	$DIRSERVER_LINE
	EOF

	let NUM=$NUM-1
done

# Set up relays

NUM=$RELAYS
while [ $NUM -gt 0 ]; do

	path=$WD/relays/relay$NUM;
	mkdir -p $path;
	cd $path
	let ORPORT=5000+$NUM
	let DIRPORT=6000+$NUM

	# Make the config file
	cat <<-EOF >$path/torrc
	TestingTorNetwork 1
	DataDirectory $path
	Log notice file $path/notice.log
	Nickname relay$NUM
	SocksPort 0
	OrPort $ORPORT
	ConnLimit 90
	Address 127.0.0.1
	DirPort $DIRPORT
	$DIRSERVER_LINE
	EOF

	let NUM=$NUM-1
done

# Set up clients

NUM=$CLIENTS
while [ $NUM -gt 0 ]; do

	path=$WD/clients/client$NUM;
	mkdir -p $path;
	cd $path
	
	let SOCKSPORT=10000+$NUM

	# Make the config file
	cat <<-EOF >$path/torrc
	TestingTorNetwork 1
	DataDirectory $path
	ConnLimit 90
	Log notice file $path/notice.log
	SocksPort $SOCKSPORT
	$DIRSERVER_LINE
	EOF

	let NUM=$NUM-1
done


cd $WD

find . -name torrc -exec bash -c "$TOR -f {} &" \;
