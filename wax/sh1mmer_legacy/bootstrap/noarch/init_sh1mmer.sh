#!/bin/busybox sh

set -eE

TMPFS_SIZE=1024M
NEWROOT_MNT=/newroot
ROOTFS_MNT=/usb

STATEFUL_MNT="$1"
STATEFUL_DEV="$2"
BOOTSTRAP_DEV="$3"
ARCHITECTURE="${4:-x86_64}"

ROOTFS_DEV=

SCRIPT_DATE="[23.02.2025]"

COLOR_RESET="\033[0m"
COLOR_BLACK_B="\033[1;30m"
COLOR_RED_B="\033[1;31m"
COLOR_GREEN="\033[0;32m"
COLOR_GREEN_B="\033[1;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_YELLOW_B="\033[1;33m"
COLOR_BLUE_B="\033[1;34m"
COLOR_MAGENTA_B="\033[1;35m"
COLOR_CYAN_B="\033[1;36m"

fail() {
	printf "%b\nAborting.\n" "$*" >&2
	cleanup || :

	sleep 1
	self_shell || :

	tail -f /dev/null
	exit 1
}

cleanup() {
	umount "$STATEFUL_MNT" || :
	umount "$ROOTFS_MNT" || :
}

trap 'fail "An unhandled error occured."' ERR

enable_input() {
	stty echo || :
}

disable_input() {
	stty -echo || :
}

self_shell() {
	printf "\n\n"
	echo "This shell has PID 1. Exit = kernel panic."
	enable_input
	printf "\033[?25h"
	exec setsid -c sh
}

unmount_and_self_shell() {
	umount "$STATEFUL_MNT" || :
	self_shell
}

notice_and_self_shell() {
	echo "Run 'exec sh1mmer_switch_root' to finish booting Sh1mmer."
	self_shell
}

poll_key() {
	local held_key
	# dont need enable_input here
	# read will return nonzero when no key pressed
	# discard stdin
	read -r -s -n 10000 -t 0.1 held_key || :
	read -r -s -n 1 -t 0.1 held_key || :
	echo "$held_key"
}

clear_line() {
	local cols
	cols=$(stty size | cut -d" " -f 2)
	printf "%-${cols}s\r"
}

pv_dircopy() {
	[ -d "$1" ] || return 1
	local apparent_bytes
	apparent_bytes=$(du -sb "$1" | cut -f 1)
	mkdir -p "$2"
	tar -cf - -C "$1" . | pv -f -s "${apparent_bytes:-0}" | tar -xf - -C "$2"
}

determine_rootfs() {
	local bootstrap_num
	bootstrap_num="$(echo "$BOOTSTRAP_DEV" | grep -o '[0-9]*$')"
	ROOTFS_DEV="$(echo "$BOOTSTRAP_DEV" | sed 's/[0-9]*$//')$((bootstrap_num + 1))"
	[ -b "$ROOTFS_DEV" ] || return 1
}

patch_new_root_sh1mmer() {
	[ -f "$NEWROOT_MNT/sbin/chromeos_startup" ] && sed -i "s/BLOCK_DEVMODE=1/BLOCK_DEVMODE=/g" "$NEWROOT_MNT/sbin/chromeos_startup"
	[ -f "$NEWROOT_MNT/usr/share/cros/dev_utils.sh" ] && sed -i "/^dev_check_block_dev_mode\(\)/a return" "$NEWROOT_MNT/usr/share/cros/dev_utils.sh"
	[ -f "$NEWROOT_MNT/sbin/chromeos-boot-alert" ] && sed -i "/^mode_block_devmode\(\)/a return" "$NEWROOT_MNT/sbin/chromeos-boot-alert"
	# disable factory-related jobs
	local file
	local disable_jobs="factory_shim factory_install factory_ui"
	for job in $disable_jobs; do
		file="$NEWROOT_MNT/etc/init/${job}.conf"
		if [ -f "$file" ]; then
			sed -i '/^start /!d' "$file"
			echo "exec true" >>"$file"
		fi
	done
}

# todo: dev console on tty4, better logging

disable_input
case "$(poll_key)" in
	x) set -x ;;
	s) unmount_and_self_shell ;;
esac

mkdir -p "$NEWROOT_MNT" "$ROOTFS_MNT"
mount -t tmpfs tmpfs "$NEWROOT_MNT" -o "size=$TMPFS_SIZE" || fail "Failed to mount tmpfs"

determine_rootfs || fail "Could not determine rootfs"
mount -o ro "$ROOTFS_DEV" "$ROOTFS_MNT" || fail "Failed to mount rootfs $ROOTFS_DEV"

printf "\033[?25l\033[2J\033[H"

printf "${COLOR_GREEN_B=}"
echo "4paI4paI4paI4pWXICAg4paI4paI4paI4pWX4paI4paI4pWXICAg4paI4paI4pWX4paI4paI4pWXICDilojilojilojilojilojilojilojilojilZfilojilojilZfilojilojilojilojilojilojilZcg4paI4paI4paI4paI4paI4paI4paI4pWXIOKWiOKWiOKWiOKWiOKWiOKWiOKVl+KWiOKWiOKVlyAg4paI4paI4pWX4paI4paI4paI4paI4paI4paI4pWXICDilojilojilojilojilojilojilZcg4paI4paI4pWXICAg4paI4paI4pWX4paI4paI4paI4paI4paI4paI4paI4pWX4paI4paI4paI4paI4paI4paI4pWXIOKWiOKWiOKVlyAgIOKWiOKWiOKVlwrilojilojilojilojilZcg4paI4paI4paI4paI4pWR4paI4paI4pWRICAg4paI4paI4pWR4paI4paI4pWRICDilZrilZDilZDilojilojilZTilZDilZDilZ3ilojilojilZHilojilojilZTilZDilZDilojilojilZfilojilojilZTilZDilZDilZDilZDilZ3ilojilojilZTilZDilZDilZDilZDilZ3ilojilojilZEgIOKWiOKWiOKVkeKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVl+KWiOKWiOKVlOKVkOKVkOKVkOKWiOKWiOKVl+KWiOKWiOKVkSAgIOKWiOKWiOKVkeKWiOKWiOKVlOKVkOKVkOKVkOKVkOKVneKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVl+KVmuKWiOKWiOKVlyDilojilojilZTilZ0K4paI4paI4pWU4paI4paI4paI4paI4pWU4paI4paI4pWR4paI4paI4pWRICAg4paI4paI4pWR4paI4paI4pWRICAgICDilojilojilZEgICDilojilojilZHilojilojilojilojilojilojilZTilZ3ilojilojilojilojilojilZcgIOKWiOKWiOKVkSAgICAg4paI4paI4paI4paI4paI4paI4paI4pWR4paI4paI4paI4paI4paI4paI4pWU4pWd4paI4paI4pWRICAg4paI4paI4pWR4paI4paI4pWRICAg4paI4paI4pWR4paI4paI4paI4paI4paI4pWXICDilojilojilojilojilojilojilZTilZ0g4pWa4paI4paI4paI4paI4pWU4pWdIArilojilojilZHilZrilojilojilZTilZ3ilojilojilZHilojilojilZEgICDilojilojilZHilojilojilZEgICAgIOKWiOKWiOKVkSAgIOKWiOKWiOKVkeKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVl+KWiOKWiOKVlOKVkOKVkOKVnSAg4paI4paI4pWRICAgICDilojilojilZTilZDilZDilojilojilZHilojilojilZTilZDilZDilojilojilZfilojilojilZEgICDilojilojilZHilZrilojilojilZcg4paI4paI4pWU4pWd4paI4paI4pWU4pWQ4pWQ4pWdICDilojilojilZTilZDilZDilojilojilZcgIOKVmuKWiOKWiOKVlOKVnSAgCuKWiOKWiOKVkSDilZrilZDilZ0g4paI4paI4pWR4pWa4paI4paI4paI4paI4paI4paI4pWU4pWd4paI4paI4paI4paI4paI4paI4paI4pWX4paI4paI4pWRICAg4paI4paI4pWR4paI4paI4pWRICDilojilojilZHilojilojilojilojilojilojilojilZfilZrilojilojilojilojilojilojilZfilojilojilZEgIOKWiOKWiOKVkeKWiOKWiOKVkSAg4paI4paI4pWR4pWa4paI4paI4paI4paI4paI4paI4pWU4pWdIOKVmuKWiOKWiOKWiOKWiOKVlOKVnSDilojilojilojilojilojilojilojilZfilojilojilZEgIOKWiOKWiOKVkSAgIOKWiOKWiOKVkSAgIArilZrilZDilZ0gICAgIOKVmuKVkOKVnSDilZrilZDilZDilZDilZDilZDilZ0g4pWa4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWd4pWa4pWQ4pWdICAg4pWa4pWQ4pWd4pWa4pWQ4pWdICDilZrilZDilZ3ilZrilZDilZDilZDilZDilZDilZDilZ0g4pWa4pWQ4pWQ4pWQ4pWQ4pWQ4pWd4pWa4pWQ4pWdICDilZrilZDilZ3ilZrilZDilZ0gIOKVmuKVkOKVnSDilZrilZDilZDilZDilZDilZDilZ0gICDilZrilZDilZDilZDilZ0gIOKVmuKVkOKVkOKVkOKVkOKVkOKVkOKVneKVmuKVkOKVnSAg4pWa4pWQ4pWdICAg4pWa4pWQ4pWdICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIA==" | base64 -d
printf "${COLOR_RESET}"
echo "MultiRechrovery is loading..."
echo "Based on Sh1mmer: https://github.com/MercuryWorkshop/Sh1mmer"
echo "Bootloader date: ${SCRIPT_DATE}"
echo "https://github.com/Shuniji-Labs/MultiRechrovery"
echo ""

echo "Copying rootfs..."
pv_dircopy "$ROOTFS_MNT" "$NEWROOT_MNT"
umount "$ROOTFS_MNT"
echo ""

SKIP_SH1MMER_PATCH=0
if [ "$(poll_key)" = "n" ]; then
	SKIP_SH1MMER_PATCH=1
	echo "SKIPPING PATCH"
	echo ""
fi

echo "Patching new root..."
printf "${COLOR_BLACK_B}"
/bin/patch_new_root.sh "$NEWROOT_MNT" "$STATEFUL_DEV"
[ "$SKIP_SH1MMER_PATCH" -eq 0 ] && patch_new_root_sh1mmer
printf "${COLOR_RESET}"
echo ""

if [ "$SKIP_SH1MMER_PATCH" -eq 0 ]; then
	echo "Copying Sh1mmer files..."
	pv_dircopy "$STATEFUL_MNT/root/noarch" "$NEWROOT_MNT" || :
	pv_dircopy "$STATEFUL_MNT/root/$ARCHITECTURE" "$NEWROOT_MNT" || :
	echo ""
fi

umount "$STATEFUL_MNT"

# write this to a file so the user can easily run this from the debug shell
cat <<EOF >/bin/sh1mmer_switch_root
#!/bin/busybox sh

if [ \$\$ -ne 1 ]; then
	echo "No PID 1. Abort."
	exit 1
fi

BASE_MOUNTS="/sys /proc /dev"
move_mounts() {
	# copied from https://chromium.googlesource.com/chromiumos/platform/initramfs/+/54ea247a6283e7472a094215b4929f664e337f4f/factory_shim/bootstrap.sh#302
	echo "Moving \$BASE_MOUNTS to $NEWROOT_MNT"
	for mnt in \$BASE_MOUNTS; do
		# \$mnt is a full path (leading '/'), so no '/' joiner
		mkdir -p "$NEWROOT_MNT\$mnt"
		mount -n -o move "\$mnt" "$NEWROOT_MNT\$mnt"
	done
	echo "Done."
}

move_mounts
echo "exec switch_root"
echo "this shouldn't take more than a few seconds"
exec switch_root "$NEWROOT_MNT" /sbin/init -v --default-console output || :
EOF
chmod +x /bin/sh1mmer_switch_root

[ "$(poll_key)" = "d" ] && notice_and_self_shell

enable_input
exec sh1mmer_switch_root || :

# should never reach here
fail "Failed to exec switch_root."
