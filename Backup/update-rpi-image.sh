#!/usr/bin/env bash
set -euo pipefail

# Paramètres par défaut
IMG="/mnt/backup/hackberry_shrunk.img"
MNT_ROOT="/mnt/img-root"
MNT_BOOT="/mnt/img-boot"

# Rsync: miroir complet pour ext4 (root)
RSYNC_ROOT_OPTS="-aHAX --numeric-ids --delete --info=stats2,progress2"
# Rsync: FAT (boot) ne supporte pas ACL/xattrs -> -a suffit
RSYNC_BOOT_OPTS="-a --delete --info=stats2,progress2"

# Exclusions pour rootfs
EXCLUDES_ROOT=(
  "--exclude=/dev/*"
  "--exclude=/proc/*"
  "--exclude=/sys/*"
  "--exclude=/run/*"
  "--exclude=/tmp/*"
  "--exclude=/mnt/*"
  "--exclude=/media/*"
  "--exclude=/lost+found"
)

require() { command -v "$1" >/dev/null 2>&1 || { echo "Manquant: $1" >&2; exit 1; }; }

cleanup() {
  set +e
  sync
  if mountpoint -q "$MNT_BOOT"; then umount "$MNT_BOOT"; fi
  if mountpoint -q "$MNT_ROOT"; then umount "$MNT_ROOT"; fi
  if [[ -n "${LOOPDEV:-}" ]]; then losetup -d "$LOOPDEV" >/dev/null 2>&1; fi
}
trap cleanup EXIT

# Prérequis
require losetup
require rsync
require mount
require findmnt
require blkid

[[ -f "$IMG" ]] || { echo "Image introuvable: $IMG" >&2; exit 1; }

mkdir -p "$MNT_ROOT" "$MNT_BOOT"

# Attacher l'image et exposer les partitions
LOOPDEV=$(losetup -Pf --show "$IMG")

P1="${LOOPDEV}p1"
P2="${LOOPDEV}p2"

# Détecter les types via blkid (fiable)
TYPE_P1=$(blkid -o value -s TYPE "$P1" 2>/dev/null || true)
TYPE_P2=$(blkid -o value -s TYPE "$P2" 2>/dev/null || true)

# Normalisation/validation
# p1 attendu: vfat/fat32; p2 attendu: ext4
if [[ -z "$TYPE_P1" || -z "$TYPE_P2" ]]; then
  echo "Avertissement: TYPE absent pour p1/p2; tentative avec valeurs par défaut." >&2
fi
[[ -z "$TYPE_P1" ]] && TYPE_P1="vfat"
[[ -z "$TYPE_P2" ]] && TYPE_P2="ext4"

# Monter explicitement par type
mount -t "$TYPE_P2" -o rw "$P2" "$MNT_ROOT"
mount -t "$TYPE_P1" -o rw "$P1" "$MNT_BOOT"

# Vérifier les montages
findmnt -n "$MNT_ROOT" >/dev/null || { echo "Root non monté"; exit 1; }
findmnt -n "$MNT_BOOT" >/dev/null || { echo "Boot non monté"; exit 1; }

# 1) Sync root -> p2 (ext4)
rsync $RSYNC_ROOT_OPTS "${EXCLUDES_ROOT[@]}" "/"/ "$MNT_ROOT/"

# 2) Sync boot -> p1 (vfat)
rsync $RSYNC_BOOT_OPTS "/boot/firmware/"/ "$MNT_BOOT/"

echo "Mise à jour OK:
- Rootfs -> $MNT_ROOT ($P2, type=$TYPE_P2)
- Boot   -> $MNT_BOOT ($P1, type=$TYPE_P1)
Image: $IMG"
