# BLUE3 root bashrc

[ -z "$PS1" ] && return

HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoredups
shopt -s histappend

reset='\[\e[0m\]'
yellow='\[\e[1;33m\]'
blue='\[\e[1;34m\]'
green='\[\e[1;32m\]'
cyan='\[\e[1;36m\]'
purple='\[\e[1;35m\]'
red='\[\e[1;31m\]'

export LESS='-R'
export EDITOR='vim'
export VISUAL='vim'

if [ "$EUID" -eq 0 ]; then
    symbol="${red}#"
else
    symbol="${green}$"
fi

PS1="\n${blue}┌─${blue}[${yellow}\u${blue}@${purple}\h ${cyan}\t${blue}]${reset} ${blue}\w${reset}\n${blue}└─${symbol}${reset} "

[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash

alias ..='cd ..'
alias ...='cd ../..'
alias l='ls -alFh --color=auto'
alias ls='ls --color=auto'
alias lh="ls -aFh -lS --color=auto | grep -v '^d'"
alias vi='vi -C -c "set nocp" -c "syn on"'
alias grep='grep --color=auto'
alias ip='ip -c'
alias meuip='curl -fsSL ifconfig.me; echo'
alias mv='mv -v'
alias cp='cp -v'
alias rm='rm -v'

if command -v grc >/dev/null 2>&1; then
    alias tail='grc tail'
    alias ping='grc ping'
    alias traceroute='grc traceroute'
    alias ps='grc ps'
    alias netstat='grc netstat'
    alias dig='grc dig'
fi

mkcd() {
    mkdir -p "$1" && cd "$1"
}

portas() {
    ss -tulpen
}

dus() {
    du -sh ./* 2>/dev/null | sort -h
}

export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"