#!/bin/bash
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

LOG_FILE="/usb_logs/stage3_user.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${GREEN}==>${NC} ${WHITE}Installing AUR Helper (Paru)...${NC}"
cd "$HOME" || exit
git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si --noconfirm

echo -e "${GREEN}==>${NC} ${WHITE}Setting up User Directories...${NC}"
sudo pacman -S xdg-user-dirs --noconfirm
xdg-user-dirs-update

echo -e "${GREEN}==>${NC} ${WHITE}Cloning Hyprdots...${NC}"
mkdir -p "$HOME/Projects" && cd "$HOME/Projects" || exit
git clone https://github.com/atherson/hyprdots
cd hyprdots/Scripts && chmod +x install.sh && ./install.sh

if [[ -f "/apps_list.txt" ]]; then
    echo -e "${GREEN}==>${NC} ${WHITE}Installing Bulk Apps...${NC}"
    sudo pacman -S --noconfirm - < /apps_list.txt
fi