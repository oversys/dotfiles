# Prompt
NL=$'\n'
PROMPT="%F{#66d9ef} %f%~${NL}%F{#ff6188}❯%F{#ffd866}❯%F{#a9dc76}❯ %b%f"

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory

# Aliases
alias ls="exa -l"
alias vim="nvim"
alias ff="fastfetch"
alias rconf="source $HOME/.zshrc"

# Pacman aliases
alias upd="sudo pacman -Syy"
alias upg="sudo pacman -Syu"
alias purge="sudo pacman -Rsn $(pacman -Qdtq)" 
alias sp="pacman -Ss"
alias gp="sudo pacman -S"
alias rp="sudo pacman -Rs"

# Key bindings
bindkey "^[[Z" end-of-line 
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# Install from Arch User Repository
auri() {
	for aurpkg in $@
	do
		git clone https://aur.archlinux.org/$aurpkg.git
		cd $aurpkg
		makepkg -si
		cd ..
		rm -rf $aurpkg
	done
}

# Search for packages on the Arch User Repository
saur() {
	response=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=search&arg=$1")

	if [ "$(echo "$response" | jq -r '.resultcount')" -eq 0 ]; then
		echo "No results found for \"$1\"."
		return 1
	fi

	RED=$'\033[4;31m'
	GRAY=$'\033[3;37m'
	NC=$'\033[0m'
	echo "$response" | jq -r --arg RED "$RED" --arg GRAY "$GRAY" --arg NC "$NC" '.results[] | "\($RED)\(.Name)\($NC) \($GRAY)(\(.URL))\($NC)\n    \(.Description)"'
}

# Change time zone
ctz() {
	echo -e "Select \e[4;33mRegion\e[0m:"
	REGIONS=("Africa" "America" "Antarctica" "Asia" "Australia" "Europe" "Pacific")
	
	select region in "${REGIONS[@]}"; do
		SELECTED_REGION=$region
		break
	done
	
	clear
	
	echo -e "Select \e[4;35mCity\e[0m:"
	CITIES=($(/bin/ls /usr/share/zoneinfo/$SELECTED_REGION))
	
	select city in "${CITIES[@]}"; do
		SELECTED_CITY=$city
		break
	done
	
	sudo timedatectl set-timezone $SELECTED_REGION/$SELECTED_CITY
}

# Downloading files
wg() { 
	for arg in $@
	do
		arr=(${(s. .)arg})
		wget -O $arr[1] --user-agent="Mozilla" $arr[2]
	done
}

# Mounting NAS
mns() { 
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		echo "Usage: mns (--options) SERVER_HOSTNAME SHARE_NAME"
		echo ""
		echo "options:"
		echo "-h, --help	 Show this help message"
		echo "-u, --username	 Mount with a username"
		echo "-m, --mount	 Mount without a username (guest/anonymous)"
		echo "-n, --unmount	 Unmount the NAS"
		echo ""
		echo "Examples:"
		echo "	mns --username myusername 192.168.0.159 homeshare"
		echo "	mns -m homeserver myshare"
		echo "	mns -n"
	elif [ "$1" = "-u" ] || [ "$1" = "--username" ]; then
		mkdir -p $HOME/shared/
		sudo mount -t cifs -o username=$2,dir_mode=0777,file_mode=0777 //$3/$4 $HOME/shared/
		cd $HOME/shared
	elif [ "$1" = "-m" ] || [ "$1" = "--mount" ]; then
		mkdir -p $HOME/shared/
		sudo mount -t cifs -o guest,dir_mode=0777,file_mode=0777 //$2/$3 $HOME/shared/
		cd $HOME/shared
	elif [ "$1" = "-n" ] || [ "$1" = "--unmount" ]; then
		cd
		sudo umount $HOME/shared/
		rmdir $HOME/shared/
	else
		echo "Usage: mns (--options) SERVER_HOSTNAME SHARE_NAME"
		echo ""
		echo "options:"
		echo "-h, --help	 Show this help message"
		echo "-u, --username	 Mount with a username"
		echo "-m, --mount	 Mount without a username (guest/anonymous)"
		echo "-n, --unmount	 Unmount the NAS"
		echo ""
		echo "Examples:"
		echo "	mns --username myusername 192.168.0.159 homeshare"
		echo "	mns -m homeserver myshare"
		echo "	mns -n"
	fi
}

# Mount Microsoft Windows Partition
mwp() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		echo "Usage: mwp (--options) /dev/sdXX"
		echo ""
		echo "options:"
		echo "-h, --help	 Show this help message"
		echo "-m, --mount	 Mount partition"
		echo "-n, --unmount	 Unmount the partition"
		echo ""
		echo "Examples:"
		echo "	mwp -m /dev/sda3"
		echo "	mwp --unmount"
	elif [ "$1" = "-m" ] || [ "$1" = "--mount" ]; then
		sudo mkdir -p /mnt/MSW/
		sudo mount $2 /mnt/MSW/
		cd /mnt/MSW/
	elif [ "$1" = "-n" ] || [ "$1" = "--unmount" ]; then
		cd $HOME/
		sudo umount /mnt/MSW/
		sudo rmdir /mnt/MSW/
	else
		echo "Usage: mwp (--options) /dev/sdXX"
		echo ""
		echo "options:"
		echo "-h, --help	 Show this help message"
		echo "-m, --mount	 Mount partition"
		echo "-n, --unmount	 Unmount the partition"
		echo ""
		echo "Examples:"
		echo "	mwp -m /dev/sda3"
		echo "	mwp --unmount"
	fi
}

# Encrypt data
sef() {
	gpg --symmetric --no-symkey-cache --cipher-algo AES256 $1
}

# Decrypt data
sdf() {
	gpg --output ${1%.gpg} --decrypt --no-symkey-cache $1
}

# Get IP Address
getip() { ip -o -4 addr list $1 | awk '{print $4}' | cut -d / -f 1 }

# Plugins
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
