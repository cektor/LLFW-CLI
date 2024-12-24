#!/bin/bash

# LLFW - Düşük Seviye Disk Biçimlendirme Aracı
# ALG Software Inc.© 2024

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Mesajlar
declare -A tr_TR=(
    ["title"]="LLFW - Düşük Seviye Disk Biçimlendirme Aracı | Fatih ÖNDER - https://github.com/cektor/LLFW-CLI"
    ["select_disk"]="Lütfen bir disk seçin:"
    ["select_method"]="Format metodunu seçin:"
    ["select_filesystem"]="İşlem Sonu dosya sistemi formatını seçin:"
    ["warning"]="UYARI"
    ["error"]="HATA"
    ["info"]="BİLGİ"
    ["confirm"]="Onay"
    ["cancel"]="İptal"
    ["root_required"]="Bu uygulama root yetkileri ile çalıştırılmalıdır!"
    ["disk_warning"]="DİKKAT: Seçilen disk üzerindeki TÜM VERİLER SİLİNECEKTİR!"
    ["continue_prompt"]="Devam etmek istiyor musunuz? (e/h)"
    ["operation_cancelled"]="İşlem iptal edildi."
    ["operation_complete"]="İşlem tamamlandı!"
    ["unmounting"]="Disk bağlantısı kesiliyor..."
    ["zero_fill"]="Sıfırlarla doldurma"
    ["random_data"]="Rastgele veri"
    ["secure_erase"]="Güvenli silme"
    ["creating_partition"]="Disk bölümü oluşturuluyor..."
    ["formatting"]="Formatlanıyor..."
    ["format_complete"]="Biçimlendirme tamamlandı!"
    ["partition_error"]="Bölüm oluşturma hatası!"
    ["format_error"]="Biçimlendirme hatası!"
    ["exit_message"]="İşlem iptal edildi. Çıkılıyor..."
)

# Root kontrolü
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${tr_TR["root_required"]}${NC}"
        exit 1
    fi
}

# Diskleri listele
list_disks() {
    echo -e "${BLUE}${tr_TR["select_disk"]}${NC}"
    echo "-----------------------------------"
    disks=( $(lsblk -d -o NAME | grep -v "NAME") )
    disk_count=${#disks[@]}

    for i in $(seq 0 $(($disk_count - 1)));
    do
        size=$(lsblk -d -o SIZE -n /dev/${disks[$i]})
        model=$(lsblk -d -o MODEL -n /dev/${disks[$i]})
        echo "$((i+1))) ${disks[$i]} - $size - $model"
    done

    echo "-----------------------------------"
    read -p "$(echo -e ${YELLOW}"Disk numarasını seçin (örn: 1): "${NC})" selected_disk_index

    if [[ $selected_disk_index -lt 1 || $selected_disk_index -gt $disk_count ]]; then
        echo -e "${RED}${tr_TR["error"]}: Geçersiz seçim!${NC}"
        exit 1
    fi

    DISK="/dev/${disks[$((selected_disk_index-1))]}"
}

# Format metodunu seç
select_method() {
    echo -e "${BLUE}${tr_TR["select_method"]}${NC}"
    echo "1) ${tr_TR["zero_fill"]}"
    echo "2) ${tr_TR["random_data"]}"
    echo "3) ${tr_TR["secure_erase"]}"
    read -p "$(echo -e ${YELLOW}"Seçim (1-3): "${NC})" method_choice
    
    case $method_choice in
        1) METHOD="zero" ;;
        2) METHOD="random" ;;
        3) METHOD="secure" ;;
        *) METHOD="zero" ;;
    esac
}

# Dosya sistemini seç
select_filesystem() {
    echo -e "${BLUE}${tr_TR["select_filesystem"]}${NC}"
    echo "1) FAT32"
    echo "2) exFAT"
    echo "3) NTFS"
    echo "4) ext4"
    echo "5) Çıkış Yap"
    read -p "$(echo -e ${YELLOW}"Seçim (1-5): "${NC})" fs_choice

    case $fs_choice in
        1) FILESYSTEM="vfat" ;;
        2) FILESYSTEM="exfat" ;;
        3) FILESYSTEM="ntfs" ;;
        4) FILESYSTEM="ext4" ;;
        5) echo -e "${RED}${tr_TR["exit_message"]}${NC}" && exit 0 ;;
        *) FILESYSTEM="vfat" ;;
    esac
}

# Onay al
get_confirmation() {
    echo -e "${RED}${tr_TR["warning"]}${NC}"
    echo -e "${RED}${tr_TR["disk_warning"]}${NC}"
    echo "Disk: $DISK"
    echo -e "${YELLOW}${tr_TR["continue_prompt"]}${NC}"
    read -p "" confirm
    
    if [[ ! $confirm =~ ^[Ee]$ ]]; then
        echo -e "${YELLOW}${tr_TR["operation_cancelled"]}${NC}"
        exit 0
    fi
}

# Diski bağlantıdan kaldır
unmount_disk() {
    echo -e "${BLUE}${tr_TR["unmounting"]}${NC}"
    umount ${DISK}* 2>/dev/null
}

# Format işlemi
format_disk() {
    case $METHOD in
        "zero")
            echo -e "${BLUE}${tr_TR["zero_fill"]}...${NC}"
            dd if=/dev/zero of=$DISK bs=1M status=progress
            ;;
        "random")
            echo -e "${BLUE}${tr_TR["random_data"]}...${NC}"
            dd if=/dev/urandom of=$DISK bs=1M status=progress
            ;;
        "secure")
            echo -e "${BLUE}${tr_TR["secure_erase"]}...${NC}"
            hdparm --security-erase NULL $DISK
            ;;
    esac
    echo -e "\n${GREEN}${tr_TR["operation_complete"]}${NC}"
}

# Seçilen dosya sistemi ile biçimlendirme
format_filesystem() {
    echo -e "${BLUE}${tr_TR["creating_partition"]}${NC}"
    (
        echo o # Yeni partition table
        echo n # Yeni partition
        echo p # Primary partition
        echo 1 # Partition number
        echo   # İlk sector
        echo   # Son sector
        echo w # Kaydet
    ) | fdisk $DISK > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        sleep 2
        echo -e "${BLUE}${tr_TR["formatting"]} ${FILESYSTEM}...${NC}"
        mkfs.$FILESYSTEM "${DISK}1" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${tr_TR["format_complete"]}${NC}"
        else
            echo -e "${RED}${tr_TR["format_error"]}${NC}"
        fi
    else
        echo -e "${RED}${tr_TR["partition_error"]}${NC}"
    fi
}

# Ana program
clear
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}${tr_TR["title"]}${NC}"
echo -e "${BLUE}======================================${NC}"

check_root
list_disks
select_method
get_confirmation
unmount_disk
format_disk
select_filesystem
format_filesystem

