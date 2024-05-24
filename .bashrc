#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'

NC="\[\033[00m\]"

PS1="\[\e[1;32m\]\u$NC:\[\033[1;29m\]\w\n\[\033[1;91m\]➜ $NC\[\033[1;99m\]"

alias ':r'='source .bashrc'
alias upd="sudo pacman -Syy"
alias upg="sudo pacman -Syyu"
ai() { sudo pacman -S $*; }
ar() { sudo pacman -R $*; }

(cat ~/.cache/wal/sequences &)
. "$HOME/.cargo/env"
