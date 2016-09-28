#!/bin/bash

device_file=$1

if [ `whoami` != "root" ]; then
	echo "Must be root. Exiting."
	exit;
fi

which wget mkfs.vfat >/dev/null 2>/dev/null
if [ $? != "0" ]; then
        echo "I need wget and mkfs.vfat (dosfstools) to work. Exiting."
        exit;
fi

if [ -z $device_file ]; then
	echo "Usage: $0 /dev/sdX"
	exit;
fi

if [ ! -b $device_file ]; then
	echo "Specified file is not a block device. Exiting."
	exit;
fi

for part in $(ls $device_file*); do
	echo "Unmounting partition $part"
	umount $part 2>/dev/null
done

echo "WARNING!"
echo "This tool will remove all partitions from specified device and create new ones."
echo "Make sure you have selected the correct one (with "parted -l", for example)."
echo "Press any key to continue..."
read -n 1

echo "Creating new partitions."
echo -e "o\nn\np\n1\n\n+100M\nt\nc\nn\np\n2\n\n\nw" | fdisk $device_file # scary part

echo "Creating and mounting new FSes."
mkfs.vfat $device_file"1"
mkdir boot 2>/dev/null
mount $device_file"1" boot

if [ $? -ne "0" ]; then
	echo "Error mounting boot FS. Exiting."
	echo "Check if mkfs.vfat (dosfstools) installed"
	exit;
fi

mkfs.ext4 $device_file"2"
mkdir root 2>/dev/null
mount $device_file"2" root

if [ $? -ne "0" ]; then
        echo "Error mounting root FS. Exiting."
        echo "Check if mkfs.vfat (dosfstools) installed"
        exit;
fi

echo "Downloading Arch image."
wget --quiet --continue --show-progress http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz

if [ $? -ne "0" ]; then
        echo "Error downloading image. Exiting: $?"
        echo "Check internet connection, permissions and free space."
        exit;
fi

echo "Writing Arch image."
bsdtar -xpf ArchLinuxARM-rpi-2-latest.tar.gz -C root
sync
mv root/boot/* boot
sync

echo "Unmounting FSes."
umount boot root

echo "Done."

