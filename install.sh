#!/bin/bash

# --- COLOR DEFINITIONS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

# UI Helpers
log_step() { echo -e "${GREEN}==>${NC} ${WHITE}$1${NC}"; }
log_err() { echo -e "${RED}ERROR:${NC} ${WHITE}$1${NC}"; }

# --- AUTOMATIC USB DETECTION ---
USB_DEV=$(df ./ | tail -1 | awk '{print $1}')
USB_DIR=$(pwd)
sed -i "s|USB_DEV=.*|USB_DEV=\"$USB_DEV\"|" ./creds.conf

source "./creds.conf"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$USB_DIR/logs/install_$TIMESTAMP"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/stage1_iso.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log_step "Stage 1: Hardware & Partitioning"
lsblk
echo -e "${GREEN}Enter Target Drive (e.g., /dev/nvme0n1):${NC}"
read -r TARGET_DRIVE

echo -e "${GREEN}Have you set partitions with cfdisk? (y/n):${NC}"
read -r HAS_PARTITIONS
[[ "$HAS_PARTITIONS" != "y" ]] && { log_err "Run: cfdisk $TARGET_DRIVE"; exit 1; }

echo -e "${GREEN}Identify Partitions:${NC}"
echo -n "BOOT: "; read -r BOOT_PART
echo -n "SWAP: "; read -r SWAP_PART
echo -n "ROOT: "; read -r ROOT_PART
echo -e "${GREEN}ROOT FS: 1)ext4 2)btrfs 3)xfs${NC}"
read -r ROOT_FS_CHOICE

# Formatting
log_step "Formatting Partitions..."
mkfs.fat -F32 "$BOOT_PART" || { log_err "Boot format failed"; exit 1; }
mkswap "$SWAP_PART" && swapon "$SWAP_PART"

if [[ "$ENCRYPT_DISK" == "true" ]]; then
    log_step "Initializing LUKS Encryption..."
    echo -n "$LUKS_PASS" | cryptsetup luksFormat "$ROOT_PART" -
    echo -n "$LUKS_PASS" | cryptsetup open "$ROOT_PART" cryptroot || { log_err "LUKS failed"; exit 1; }
    ROOT_MAPPER="/dev/mapper/cryptroot"
else
    ROOT_MAPPER="$ROOT_PART"
fi

case "$ROOT_FS_CHOICE" in
    1) mkfs.ext4 "$ROOT_MAPPER" ;;
    2) mkfs.btrfs "$ROOT_MAPPER" ;;
    3) mkfs.xfs "$ROOT_MAPPER" ;;
esac

mount "$ROOT_MAPPER" /mnt
mkdir -p /mnt/boot && mount "$BOOT_PART" /mnt/boot

# Bridge & Install
mkdir -p /mnt/usb_logs
mount --bind "$LOG_DIR" /mnt/usb_logs

log_step "Pacstrapping System..."
pacstrap /mnt base "$KERNEL" linux-firmware base-devel git sudo nano || { log_err "Pacstrap failed"; exit 1; }
genfstab -U /mnt >> /mnt/etc/fstab

cp "creds.conf" "chroot_setup.sh" "post_install.sh" /mnt/
[[ -f "apps_list.txt" ]] && cp "apps_list.txt" /mnt/

log_step "Entering Chroot..."
arch-chroot /mnt /bin/bash ./chroot_setup.sh

# Cleanup
umount -l /mnt/usb_logs
umount -R /mnt
[[ "$ENCRYPT_DISK" == "true" ]] && cryptsetup close cryptroot
log_step "Success! Rebooting in 10s. REMOVE USB!"
sleep 10 && reboot