#!/bin/bash

source common.sh

mkdir -p "$WD/authorities/"
mkdir -p "$WD/relays/"
mkdir -p "$WD/clients/"

# Set up authorities

DIRSERVER_LINE=

# Make authority keys
NUM=$AUTHORITIES
while [ $NUM -gt 0 ]; do
	path="$WD/authorities/auth$NUM";
	mkdir -p "$path";
	cd "$path";
	let ORPORT=3000+$NUM
	let DIRPORT=4000+$NUM

	cat <<-EOF >"$path/torrc.tmp"
	DirServer test 127.0.0.1:1 0000000000000000000000000000000000000000
	OrPort 1
	EOF

	FP=`"$TOR" --quiet --list-fingerprint --DataDirectory "$path" -f torrc.tmp \
	| cut -f 2,3,4,5,6,7,8,9,10,11 -d " " | sed 's/ //g'`;

	rm -rf "$path/torrc.tmp"

	# Make a dummy password for this authority
	echo $NUM$NUM$NUM$NUM > password

	if [ ! -f "$path/authority_identity_key" ]; then
		exec 5<> password
		"$GENCERT" --create-identity-key --passphrase-fd 5
		exec 5>&-

		mv authority_certificate authority_signing_key keys/
	fi
	V3ID=`grep fingerprint keys/authority_certificate | cut -f 2 -d " "`;
	
	DIRSERVER_LINE="DirServer authority$NUM v3ident=$V3ID orport=$ORPORT \
no-v2 127.0.0.1:$DIRPORT $FP"$'\n'"$DIRSERVER_LINE";

	let NUM=$NUM-1 || true
done

# Configure them

# Set up the default shared config for all nodes
SHARED_CONFIG="
TestingTorNetwork 1\n\
DataDirectory \$path\n\
RunAsDaemon 1\n\
ConnLimit \$CONNLIMIT\n\
Nickname \$type\$NUM\n\
ShutdownWaitLength 0\n\
PidFile $WD/\$type\$NUM.pid\n\
Log notice file \$path/notice.log"

NUM=$AUTHORITIES
while [ $NUM -gt 0 ]; do

	type=auth
	path="$WD/authorities/$type$NUM";
	let ORPORT=3000+$NUM
	let DIRPORT=4000+$NUM

	# Make the config file
	eval conf=\"$SHARED_CONFIG\"
	echo -e $conf >"$path/torrc"

	cat <<-EOF >>"$path/torrc"
	SocksPort 0
	OrPort $ORPORT
	Address 127.0.0.1
	DirPort $DIRPORT
	AuthoritativeDirectory 1
	V3AuthoritativeDirectory 1
	ContactInfo auth$NUM@test.test
	ExitPolicy reject *:*
	$DIRSERVER_LINE
	EOF

	let NUM=$NUM-1 || true
done

# Set up relays

NUM=$RELAYS
while [ $NUM -gt 0 ]; do

	type=relay
	path="$WD/relays/$type$NUM";
	mkdir -p "$path";
	cd "$path"
	let ORPORT=5000+$NUM
	let DIRPORT=6000+$NUM

	# Make the config file
	eval conf=\"$SHARED_CONFIG\"
	echo -e $conf >"$path/torrc"

	cat <<-EOF >>"$path/torrc"
	SocksPort 0
	OrPort $ORPORT
	Address 127.0.0.1
	DirPort $DIRPORT
	$DIRSERVER_LINE
	EOF

	let NUM=$NUM-1 || true
done

# Set up clients

NUM=$CLIENTS
while [ $NUM -gt 0 ]; do

	type=client
	path="$WD/clients/$type$NUM";
	mkdir -p "$path";
	cd "$path"
	
	let SOCKSPORT=10000+$NUM

	# Make the config file
	eval conf=\"$SHARED_CONFIG\"
	echo -e $conf >"$path/torrc"

	cat <<-EOF >>"$path/torrc"
	SocksPort $SOCKSPORT
	$DIRSERVER_LINE
	EOF

	let NUM=$NUM-1 || true
done
