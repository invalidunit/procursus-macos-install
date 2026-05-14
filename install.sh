#!/bin/sh -


_arch="$(uname -m)"
_p_path='/opt/procursus'


_check_null_uid(){
	unset _uids i i_max
	_uids="$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -ugr)"
	i='1'
	i_max='498'
	while [ '1' -le '2' ]; do
		if ! printf '%s\n' "${_uids}" | grep -q "^${i_max}$"; then
			echo "${i_max}"
			break
		fi
		i_max="$((i_max-1))"
	done
}

_check_and_add_PATH(){
	if [ -f "${1}" ]; then
		if ! grep '^PATH' "${1}" | grep -q '/opt/procursus/'; then
			printf '%s\n' 'export PATH=/opt/procursus/sbin:/opt/procursus/bin:/opt/procursus/local/sbin:/opt/procursus/local/bin:$HOME/bin:$PATH' >>"${1}"
		fi
	fi
}

_remove_PATH(){
	if [ -f "${1}" ]; then
		sed -i.$$.bak "\|^export PATH=/opt/procursus/sbin:/opt/procursus/bin:/opt/procursus/local/sbin:/opt/procursus/local/bin:\$HOME/bin:\$PATH$|d" ~/.zshrc && rm ~/.zshrc.$$.bak
	fi
}

_remove_procursus(){
	echo '[*] Remove installed Procursus...'
	sudo rm -rf "${_p_path}"
	_remove_PATH "$(readlink -f ~/.zshrc)"
	echo '[=] Done'
}

case "${1}" in
	-h|--help)
		printf '%s\n'  "Usage: ${0} [options]

Options:
	--help			Print this help
	--install		Install or Remove and Reinstall Procursus
	--remove		Remove Procursus"
		;;
	--install)
		if [ -d "${_p_path}" ]; then
			_remove_procursus
		fi
		echo "[*] Download Bootstrap(${_arch})..."
		curl -L "https://invalidunit.github.io/procursus-macos-install/bootstrap-darwin-${_arch}.tar" -o "/tmp/bootstrap-$$.tar"
		if ! tar -tf "/tmp/bootstrap-$$.tar" 2>>/dev/null 1>>/dev/null; then
			echo '[x] Failed to download Bootstrap'
			rm -f "/tmp/bootstrap-$$.tar"
			exit 1
		fi
		echo '[=] Done'
		sudo echo '[*] Extracting files...'
		sudo tar -xpkf "/tmp/bootstrap-$$.tar" -C / || :
		rm -f "/tmp/bootstrap-$$.tar"
		echo '[=] Done'
		if id _apt 2>>/dev/null 1>>/dev/null; then
			echo "[*] APT Sandbox User already exists(uid:$(id -u _apt)), skip creating..."
		else
			# add unprivileged user for the apt methods
			sudo dscl . -create /Users/_apt UserShell /usr/bin/false
			sudo dscl . -create /Users/_apt NSFHomeDirectory /var/empty
			sudo dscl . -create /Users/_apt PrimaryGroupID -1
			sudo dscl . -create /Users/_apt UniqueID "$(_check_null_uid)"
			sudo dscl . -create /Users/_apt RealName "APT Sandbox User"
			if id _apt 2>>/dev/null 1>>/dev/null; then
				echo "[*] User \"_apt\"(uid:$(id -u _apt)) has been added"
			else
				echo '[x] Unknown Error: Unable to create user "_apt"'
			fi
		fi
		export PATH=/opt/procursus/sbin:/opt/procursus/bin:/opt/procursus/local/sbin:/opt/procursus/local/bin:$HOME/bin:$PATH
		sudo apt update
		sudo apt dist-upgrade -o DPkg::Options::=--force-confdef -y --allow-downgrades || :
		sudo apt install -o DPkg::Options::=--force-confdef -y apt-utils zstd lz4 xz-utils
		_check_and_add_PATH "$(readlink -f ~/.zshrc)"
		echo '[=] All Done, Have fun!'
		;;
	--remove)
		_remove_procursus
		;;
esac
