#!/usr/bin/env bash

# Copyright (C) 2007-2016 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions
# of the GNU General Public License v.2.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA


SKIP_WITH_LVMPOLLD=1

. lib/inittest

aux prepare_vg 3 256

which mkfs.xfs || skip

# Tests require a libblkid version that shows FSLASTBLOCK
lvcreate -n $lv1 -L 300 $vg
mkfs.xfs -f "$DM_DEV_DIR/$vg/$lv1"
blkid -p "$DM_DEV_DIR/$vg/$lv1" | grep FSLASTBLOCK || skip
lvchange -an $vg
lvremove $vg/$lv1

mount_dir="mnt_lvresize_cr"
mkdir -p "$mount_dir"

# dm-crypt device on lv
cr="$PREFIX-$lv-cr"

# lvextend ext4 on LUKS1
lvcreate -n $lv -L 256M $vg
echo 93R4P4pIqAH8 | cryptsetup luksFormat -i1 --type luks1 "$DM_DEV_DIR/$vg/$lv"
echo 93R4P4pIqAH8 | cryptsetup luksOpen "$DM_DEV_DIR/$vg/$lv" $cr
mkfs.ext4 /dev/mapper/$cr
mount /dev/mapper/$cr "$mount_dir"
dd if=/dev/zero of="$mount_dir/zeros1" bs=1M count=200 conv=fdatasync
df --output=size "$mount_dir" |tee df1
lvextend -L+200M --fs resize $vg/$lv
check lv_field $vg/$lv lv_size "456.00m"
df --output=size "$mount_dir" |tee df2
not diff df1 df2
umount "$mount_dir"
cryptsetup close $cr
lvchange -an $vg/$lv
lvremove $vg/$lv

# lvreduce ext4 on LUKS1
lvcreate -n $lv -L 456M $vg
echo 93R4P4pIqAH8 | cryptsetup luksFormat -i1 --type luks1 "$DM_DEV_DIR/$vg/$lv"
echo 93R4P4pIqAH8 | cryptsetup luksOpen "$DM_DEV_DIR/$vg/$lv" $cr
mkfs.ext4 /dev/mapper/$cr
mount /dev/mapper/$cr "$mount_dir"
dd if=/dev/zero of="$mount_dir/zeros1" bs=1M count=200 conv=fdatasync
df --output=size "$mount_dir" |tee df1
lvresize -L-100M --yes --fs resize $vg/$lv
check lv_field $vg/$lv lv_size "356.00m"
df --output=size "$mount_dir" |tee df2
not diff df1 df2
umount "$mount_dir"
cryptsetup close $cr
lvchange -an $vg/$lv
lvremove $vg/$lv

# lvextend xfs on LUKS1
lvcreate -n $lv -L 256M $vg
echo 93R4P4pIqAH8 | cryptsetup luksFormat -i1 --type luks1 "$DM_DEV_DIR/$vg/$lv"
echo 93R4P4pIqAH8 | cryptsetup luksOpen "$DM_DEV_DIR/$vg/$lv" $cr
mkfs.xfs /dev/mapper/$cr
mount /dev/mapper/$cr "$mount_dir"
dd if=/dev/zero of="$mount_dir/zeros1" bs=1M count=200 conv=fdatasync
df --output=size "$mount_dir" |tee df1
lvextend -L+200M --fs resize $vg/$lv
check lv_field $vg/$lv lv_size "456.00m"
df --output=size "$mount_dir" |tee df2
not diff df1 df2
umount "$mount_dir"
cryptsetup close $cr
lvchange -an $vg/$lv
lvremove $vg/$lv

# lvreduce xfs on LUKS1
lvcreate -n $lv -L 456M $vg
echo 93R4P4pIqAH8 | cryptsetup luksFormat -i1 --type luks1 "$DM_DEV_DIR/$vg/$lv"
echo 93R4P4pIqAH8 | cryptsetup luksOpen "$DM_DEV_DIR/$vg/$lv" $cr
mkfs.xfs /dev/mapper/$cr
mount /dev/mapper/$cr "$mount_dir"
dd if=/dev/zero of="$mount_dir/zeros1" bs=1M count=200 conv=fdatasync
df --output=size "$mount_dir" |tee df1
# xfs cannot be reduced
not lvresize -L-100M --yes --fs resize $vg/$lv
check lv_field $vg/$lv lv_size "456.00m"
df --output=size "$mount_dir" |tee df2
diff df1 df2
umount "$mount_dir"
cryptsetup close $cr
lvchange -an $vg/$lv
lvremove $vg/$lv

# lvextend ext4 on plain crypt (no header)
lvcreate -n $lv -L 256M $vg
echo 93R4P4pIqAH8 | cryptsetup create $cr "$DM_DEV_DIR/$vg/$lv"
mkfs.ext4 /dev/mapper/$cr
mount /dev/mapper/$cr "$mount_dir"
dd if=/dev/zero of="$mount_dir/zeros1" bs=1M count=200 conv=fdatasync
df --output=size "$mount_dir" |tee df1
# fails when no fs is found for --fs resize
not lvextend -L+200M --yes --fs resize $vg/$lv
check lv_field $vg/$lv lv_size "256.00m"
df --output=size "$mount_dir" |tee df2
diff df1 df2
umount "$mount_dir"
cryptsetup close $cr
lvchange -an $vg/$lv
lvremove $vg/$lv

# lvreduce ext4 on plain crypt (no header)
lvcreate -n $lv -L 456M $vg
echo 93R4P4pIqAH8 | cryptsetup create $cr "$DM_DEV_DIR/$vg/$lv"
mkfs.ext4 /dev/mapper/$cr
mount /dev/mapper/$cr "$mount_dir"
dd if=/dev/zero of="$mount_dir/zeros1" bs=1M count=200 conv=fdatasync
df --output=size "$mount_dir" |tee df1
# fails when no fs is found for --fs resize
not lvresize -L-100M --yes --fs resize $vg/$lv
check lv_field $vg/$lv lv_size "456.00m"
df --output=size "$mount_dir" |tee df2
diff df1 df2
umount "$mount_dir"
cryptsetup close $cr
lvchange -an $vg/$lv
lvremove $vg/$lv

# test with LUKS2?

vgremove -ff $vg
