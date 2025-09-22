#!/bin/bash
# Script imager Hackberry !! ATTENTION PREND DU TEMPS !!

# === CONFIGURATION === #
SD_LABEL="SD_BACKUP"                       # Label de la MicroSD
SD_MOUNT_POINT="/mnt/backup"               # Point de montage de la MicroSD
IMAGE_NAME="hackberry.img"                  # Nom de l'image finale
LOG_FILE="dd.log"                           # Nom du fichier de log

SSD_SOURCE="/dev/nvme0n1"                  # Disque source à copier
BS_SIZE="16M"                               # Taille de bloc pour dd (16M ok avec 8go de RAM)

# === Vérification que la SD est bien montée ===
DEVICE=$(blkid -L "$SD_LABEL")

if [ -z "$DEVICE" ]; then
    echo "[!] Aucun disque avec le label $SD_LABEL trouvé. Vérifie ta SD."
    exit 1
fi

# Vérifier que le point de montage correspond au label
MOUNTED=$(lsblk -o NAME,LABEL,MOUNTPOINT | grep "$SD_LABEL" | awk '{print $3}')

if [ "$MOUNTED" != "$SD_MOUNT_POINT" ]; then
    echo "[!] Le disque $SD_LABEL n'est pas monté sur $SD_MOUNT_POINT"
    echo "    Il est monté sur : $MOUNTED"
    exit 1
fi

# === Création de l'image ===
FULL_PATH="$SD_MOUNT_POINT/$IMAGE_NAME"
LOG_PATH="$SD_MOUNT_POINT/$LOG_FILE"

echo "[*] Création de l'image du SSD ($SSD_SOURCE) vers $FULL_PATH"
echo "[*] La progression sera enregistrée dans $LOG_PATH"

# Lancer dd en arrière-plan avec nohup et redirection du log
sudo sh -c "nohup dd if=$SSD_SOURCE of=$FULL_PATH bs=$BS_SIZE conv=fsync status=progress > $LOG_PATH 2>&1 &"

echo "[*] Commande dd lancée en arrière-plan. Utilise :"
echo "    tail -f $LOG_PATH"
echo "[*] Le script est terminé, dd continue en arrière-plan."
