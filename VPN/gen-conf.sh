#!/bin/bash

CLIENT_NAME=$1
OUTPUT_DIR="$HOME/client-configs/files"
mkdir -p "$OUTPUT_DIR"

BASE_CONFIG="$HOME/client-configs/base.conf"  # fichier avec la config de base (sans certificats)

cat $BASE_CONFIG \
    <(echo -e '<ca>') \
    $HOME/openvpn-ca/pki/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    $HOME/openvpn-ca/pki/issued/${CLIENT_NAME}.crt \
    <(echo -e '</cert>\n<key>') \
    $HOME/openvpn-ca/pki/private/${CLIENT_NAME}.key \
    <(echo -e '</key>\n<tls-auth>') \
    $HOME/openvpn-ca/ta.key \
    <(echo -e '</tls-auth>') \
    > "$OUTPUT_DIR/${CLIENT_NAME}.ovpn"

echo "Fichier client généré : $OUTPUT_DIR/${CLIENT_NAME}.ovpn"
