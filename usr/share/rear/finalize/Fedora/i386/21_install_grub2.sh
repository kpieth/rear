#  This  script is an improvement over the default grub-install '(hd0)'
#
# However the following issues still exist:
#
#  * We don't know what the first disk will be, so we cannot be sure the MBR
#    is written to the correct disk(s). That's why we make all disks bootable.
#
#  * There is no guarantee that GRUB was the boot loader used originally. One
#    solution is to save and restore the MBR for each disk, but this does not
#    guarantee a correct boot-order, or even a working boot-lader config (eg.
#    GRUB stage2 might not be at the exact same location)

# Only for GRUB2 - GRUB Legacy will be handled by its own script
[[ $(type -p grub-probe) || $(type -p grub2-probe) ]] || return

LogPrint "Installing GRUB2 boot loader"
mount -t proc none /mnt/local/proc
#for i in /dev /dev/pts /proc /sys; do mount -B $i /mnt/local${i} ; done

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]]; then

    # Check if we find GRUB where we expect it
    [[ -d "/mnt/local/boot" ]]
    StopIfError "Could not find directory /boot"
    [[ -d "/mnt/local/boot/grub2" ]]
    StopIfError "Could not find directory /boot/grub2"
    [[ -r "/mnt/local/boot/grub2/grub.cfg" ]]
    LogIfError "Unable to find /boot/grub2/grub.cfg."

    # Find exclusive partitions belonging to /boot (subtract root partitions from deps)
    bootparts=$( (find_partition fs:/boot; find_partition fs:/) | sort | uniq -u )
    grub_prefix=/grub
    if [[ -z "$bootparts" ]]; then
        bootparts=$(find_partition fs:/)
        grub_prefix=/boot/grub2
    fi
    # Should never happen
    [[ "$bootparts" ]]
    BugIfError "Unable to find any /boot partitions"

    # Find the disks that need a new GRUB MBR
    disks=$(grep '^disk ' $LAYOUT_FILE | cut -d' ' -f2)
    [[ "$disks" ]]
    StopIfError "Unable to find any disks"

    for disk in $disks; do
        # Use first boot partition by default
        part=$(echo $bootparts | cut -d' ' -f1)

        # Use boot partition that matches with this disk, if any
        for bootpart in $bootparts; do
            bootdisk=$(find_disk "$bootpart")
            if [[ "$disk" == "$bootdisk" ]]; then
                part=$bootpart
                break
            fi
        done

        # Find boot-disk and partition number
        bootdisk=$(find_disk "$part")
        partnr=${part#$bootdisk}
        partnr=${partnr#p}
        partnr=$((partnr - 1))

        if [[ "$bootdisk" == "$disk" ]]; then
            #chroot /mnt/local grub2-mkconfig -o /boot/grub2/grub.cfg
	    #chroot /mnt/local grub2-install "$bootdisk"
	    grub2-install --root-directory=/mnt/local/ $bootdisk
        else
            chroot /mnt/local grub2-mkconfig -o /boot/grub2/grub.cfg
	    #chroot /mnt/local grub2-install "$bootdisk"
	    grub2-install --root-directory=/mnt/local/ $bootdisk
        fi

        if (( $? == 0 )); then
            NOBOOTLOADER=
        fi
    done
fi

if [[ "$NOBOOTLOADER" ]]; then
    if chroot /mnt/local grub2-install "$disk" >&2 ; then
        NOBOOTLOADER=
    fi
fi

#for i in /dev /dev/pts /proc /sys; do umount  /mnt/local${i} ; done
umount /mnt/local/proc
