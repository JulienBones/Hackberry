#!/usr/bin/env bash
set -euo pipefail

# Paramètres par défaut
IMG="/mnt/backup/hackberry_shrunk.img"
MNT_ROOT="/mnt/img-root"
MNT_BOOT="/mnt/img-boot"
GROW_SIZE="+2G"   # Taille ajoutée si espace faible

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
  "--exclude=/var/log/*"
  "--exclude=/var/cache/*"
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
for cmd in losetup rsync mount findmnt blkid df resize2fs parted e2fsck; do
  require "$cmd"
done

[[ -f "$IMG" ]] || { echo "Image introuvable: $IMG" >&2; exit 1; }

mkdir -p "$MNT_ROOT" "$MNT_BOOT"

# Fonction de montage des partitions
mount_partitions() {
  LOOPDEV=$(losetup -Pf --show "$IMG")
  P1="${LOOPDEV}p1"
  P2="${LOOPDEV}p2"

  TYPE_P1=$(blkid -o value -s TYPE "$P1" 2>/dev/null || true)
  TYPE_P2=$(blkid -o value -s TYPE "$P2" 2>/dev/null || true)
  [[ -z "$TYPE_P1" ]] && TYPE_P1="vfat"
  [[ -z "$TYPE_P2" ]] && TYPE_P2="ext4"

  mount -t "$TYPE_P2" -o rw "$P2" "$MNT_ROOT"
  mount -t "$TYPE_P1" -o rw "$P1" "$MNT_BOOT"
}

# Monter au départ
mount_partitions

# Vérifier espace dispo
AVAIL=$(df --output=avail -k "$MNT_ROOT" | tail -1)
if (( AVAIL < 200000 )); then
  echo "⚠️  Espace faible ($((AVAIL/1024)) Mo). Agrandissement de l'image de $GROW_SIZE..."
  cleanup
  truncate -s "$GROW_SIZE" "$IMG"
  LOOPDEV=$(losetup -Pf --show "$IMG")
  P2="${LOOPDEV}p2"
  parted -s "$LOOPDEV" resizepart 2 100%
  e2fsck -f "$P2"
  resize2fs "$P2"
  cleanup
  mount_partitions
fi

# Vérifier montages
findmnt -n "$MNT_ROOT" >/dev/null || { echo "Root non monté"; exit 1; }
findmnt -n "$MNT_BOOT" >/dev/null || { echo "Boot non monté"; exit 1; }

# 1) Sync root -> p2 (ext4)
rsync $RSYNC_ROOT_OPTS "${EXCLUDES_ROOT[@]}" "/"/ "$MNT_ROOT/"

# 2) Sync boot -> p1 (vfat)
rsync $RSYNC_BOOT_OPTS "/boot/firmware/"/ "$MNT_BOOT/"

echo "Mise à jour OK:
- Rootfs -> $MNT_ROOT ($P2)
- Boot   -> $MNT_BOOT ($P1)
Image: $IMG"

date >> /var/log/auto-save.log
