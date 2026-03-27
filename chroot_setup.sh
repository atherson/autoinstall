#!/bin/bash
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

LOG_FILE="/usb_logs/stage2_chroot.log"
exec > >(tee -a "$LOG_FILE") 2>&1
source "/creds.conf"

echo -e "${GREEN}==>${NC} ${WHITE}Configuring Timezone: $REGION/$CITY...${NC}"
ln -sf /usr/share/"$ZONEINFO"/"$REGION"/"$CITY" /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

echo -e "${GREEN}==>${NC} ${WHITE}Setting Passwords and Users...${NC}"
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

echo -e "${GREEN}==>${NC} ${WHITE}Installing Desktop & Database...${NC}"
pacman -S --noconfirm grub efibootmgr hyprland wayland sddm networkmanager mariadb

echo -e "${GREEN}==>${NC} ${WHITE}Initializing MariaDB Service...${NC}"
mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
systemctl enable mariadb
systemctl enable sddm
systemctl enable NetworkManager

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# First Boot Script
USER_HOME="/home/$USERNAME"
FIRST_BOOT="$USER_HOME/.config/hypr/first_boot.sh"
mkdir -p "$USER_HOME/.config/hypr"
cat <<EOF > "$FIRST_BOOT"
#!/bin/bash
kitty --title "First Boot" bash -c "echo 'Welcome, $USERNAME! Installation logs are on your USB.'; sleep 10" &
sed -i '/first_boot.sh/d' "$USER_HOME/.config/hypr/hyprland.conf"
rm "\$0"
EOF
chmod +x "$FIRST_BOOT"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config"
echo "exec-once = $FIRST_BOOT" >> "$USER_HOME/.config/hypr/hyprland.conf"

echo -e "${GREEN}==>${NC} ${WHITE}Handing over to Post-Install...${NC}"
su - "$USERNAME" -c "bash /post_install.sh"
exit