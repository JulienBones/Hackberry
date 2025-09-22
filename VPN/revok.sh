#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage : $0 NOM_CLIENT"
  exit 1
fi

CLIENT_NAME=$1
EASYRSA_DIR="$HOME/openvpn-ca/easy-rsa"      # Modifier au besoin
OPENVPN_DIR="/etc/openvpn"   # Répertoire de configuration OpenVPN

cd "$EASYRSA_DIR" || { echo "Répertoire Easy-RSA introuvable"; exit 1; }

# Révoc du certif
./easyrsa revoke "$CLIENT_NAME" || { echo "Erreur lors de la révocation du certificat"; exit 1; }

# Génération de la CRL
./easyrsa gen-crl || { echo "Erreur lors de la génération de la CRL"; exit 1; }

# Copie de la CRL 
sudo cp pki/crl.pem "$OPENVPN_DIR/"
sudo chmod 644 "$OPENVPN_DIR/crl.pem"

# Redémarrage du service
sudo systemctl restart openvpn@server

echo "Certificat client '$CLIENT_NAME' révoqué, liste CRL mise à jour et serveur redémarré."
