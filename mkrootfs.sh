IMG=rootfs.img
DIR=mnt
qemu-img create $IMG 4g
mkfs.ext4 $IMG
mkdir $DIR
sudo mount -o loop $IMG $DIR
sudo debootstrap --arch amd64 buster $DIR
sudo umount $DIR
rmdir $DIR
