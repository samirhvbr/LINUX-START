#!/usr/bin/env bash

export TERM="${TERM:-xterm-256color}"

color() {
    tput setaf "$1" 2>/dev/null || true
}

up_seconds="$(cut -d. -f1 /proc/uptime)"
secs=$((up_seconds % 60))
mins=$((up_seconds / 60 % 60))
hours=$((up_seconds / 3600 % 24))
days=$((up_seconds / 86400))
uptime_value="$(printf '%d days, %02dh%02dm%02ds' "$days" "$hours" "$mins" "$secs")"

read -r one five fifteen _ < /proc/loadavg

blue="\033[34m"
white="\033[97m"

echo -e "
${blue}
                                    BLUE3 INTERNET
 ____  _            ____            $(date +"%A, %e %B %Y, %R:%S")
|  _ \\| |          |___ \\           $(uname -srmo)
| |_) | |_   _  ___  __) |
|  _ <| | | | |/ _ \\|__ <           Uptime.............: ${uptime_value}
| |_) | | |_| |  __/___) |          Memory.............: $(awk '/MemFree/ {print $2}' /proc/meminfo)kB (Free) / $(awk '/MemTotal/ {print $2}' /proc/meminfo)kB (Total)
|____/|_|\\__,_|\\___|____/           CPU Info...........: $(awk -F: '/model name/ {print substr($2,2); exit}' /proc/cpuinfo)
                                    CPU Load...........: ${one}, ${five}, ${fifteen} (1, 5, 15 min)

${white}
"

for i in {16..21} {21..16}; do
    echo -en "\e[48;5;${i}m     \e[0m"
done

echo
echo