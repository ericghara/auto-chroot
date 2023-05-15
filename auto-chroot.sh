#!/bin/bash
# Script to chroot into another bash environment
# Useful for fixing boot problems via a live cd, live usb or from another working bash environment

# Default settings
LINUX="/mnt/gentoo"
BLK_LINUX="/dev/nvme0n1p3"
BOOT="$LINUX/boot"
BLK_BOOT="/dev/nvme0n1p1"

# Font Colors
NC='\033[0m' BLACK='\033[0;30m' GRAY='\033[1;30m' RED='\033[0;31m' LTRED='\033[1;31m' GREEN='\033[0;32m'
LTGREEN='\033[1;32m' BROWN='\033[0;33m' YELLOW='\033[1;33m' BLUE='\033[0;34m' LTBLUE='\033[1;34m' PURPLE='\033[0;35m'
LTPURPLE='\033[1;35m' CYAN='\033[0;36m' LTCYAN='\033[1;36m' LTGRAY='\033[0;37m' WHITE='\033[1;37m'

echo -e "\n${WHITE}************************************************************${NC}"
echo -e "${LTBLUE} This script will chroot you into another bash environment. ${NC}"
echo -e "${WHITE}************************************************************${NC}"

option_text=( "Objects" "Mount point - Linux Root:" "Block Device - Linux Root:" "Mount point - Boot:" "Block Device - Boot:" )
option_list=( "Paths${NC}" "$LINUX" "$BLK_LINUX" "$BOOT" "$BLK_BOOT" )
num_list=( "${LTBLUE}##${LTGREEN}" "${LTGREEN}1)${NC}" "${LTGREEN}2)${NC}" "${LTGREEN}3)${NC}" "${LTGREEN}4)${NC}" )
# Display devices and paths
while [ true ] ; do
  echo -e "\n${LTBLUE}@${WHITE} Currently configured directory & device locations ${LTBLUE}@${NC}" '\n'
  for (( i=0; i<${#option_text[@]}; i++ )) ; do
    printf "%-3b %-30b %-b\n" "${num_list[$i]}" "${option_text[$i]}" "${option_list[$i]}"
  done
  echo -en "${LTBLUE}* ${NC}" ; read -p "Enter path you wish to modify (1-4 or c to continue): " inp
    if [[ "$inp" == "" || "$inp" == "c" ]] ; then
      break
    # stderr is being redirected to /dev/null to sheild user from these inconsequential errors - usually from unusual characters
    elif [[ "1" -le "$inp" && "$inp" -le "4" ]] 2> /dev/null ; then
      echo -en "${LTBLUE}* ${NC}" ; read -p "Enter path to ${option_text[$inp]} " option_list[$inp]
    else
      echo -e "'$inp' is not an option.  Let's start over!" '\n'
    fi
done

# Update paths
LINUX="${option_list[1]}"
BLK_LINUX="${option_list[2]}"
BOOT="${option_list[3]}"
BLK_BOOT="${option_list[4]}"
# Create paths if required
for p in "$LINUX" "$BOOT" ; do
  if [[ ! -d "$p" ]] ; then
    while [ true  ] ; do
      echo -en "${LTBLUE}* ${NC}" ; read -p "'$p' does not exist.  Would you like to create it? (y/n) " -n 1 key <&1 ; echo
      if [[ "$key" =~ ^(y|Y) ]] ; then
        mkdir -p "$p"
        echo -e "${GREEN}*${NC} Created: "$p""
        break
      elif [[ "$key" =~ ^(n|N) ]] ; then
        echo -e "${LTRED}* ${NC}I cannot proceed without a root directory. ${WHITE}:(${NC}"
        exit 0
      else
        echo -e "'$key' is not an option.  Let's try again!"
      fi
    done
  fi
done


DEV_LIST=( "$BLK_LINUX" "$BLK_BOOT" )
MSG_LIST=( "Linux Root" "Boot" )
len_list=${#MSG_LIST[@]}
# Error check block device inputs
for (( i=0; i<${len_list}; i++ )) ; do
  while [[ ! -b "${DEV_LIST[$i]}" ]] ; do
    echo -e "${YELLOW}*${NC} ${DEV_LIST[$i]} isn't a recognized device."
    echo -en "${LTBLUE}* ${NC}" ; read -p "Enter path to '${MSG_LIST[$i]}' partition block device (ex: /dev/sda2) or x to exit: " f
    if [[ "$f" =~ ^(x|X) ]] ; then
      echo -e "${PURPLE}Bye Bye${LTRED}!${NC}"
      exit 0
    fi
    DEV_LIST[$i]=$f
  done
done
BLK_LINUX="${DEV_LIST[0]}"
BLK_BOOT="${DEV_LIST[1]}"

# Prepare mounts
mount $BLK_LINUX $LINUX
mount $BLK_BOOT $BOOT
mount --types proc /proc $LINUX/proc 
mount --rbind /sys $LINUX/sys 
mount --make-rslave $LINUX/sys 
mount --rbind /dev $LINUX/dev 
mount --make-rslave $LINUX/dev
mount -t efivarfs efivarfs $LINUX/sys/firmware/efi/efivars
test -L /dev/shm && rm /dev/shm && mkdir /dev/shm 
mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm 
chmod 1777 /dev/shm
cp /etc/resolv.conf $LINUX/etc
echo -e "${LTGREEN}---------${LTBLUE}---------${WHITE}About to chroot${LTBLUE}---------${LTGREEN}------------${NC}"
chroot $LINUX /bin/bash --login
exit 0
