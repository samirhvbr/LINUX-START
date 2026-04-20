#!/usr/bin/env bash

set -Eeuo pipefail

VERSION="23.1"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
ENV_FILE="${BLUE3_ENV_FILE:-$SCRIPT_DIR/.env}"
VERSION_FILE="$SCRIPT_DIR/VERSION"

# ==========================
# CORES
# ==========================
RED="\e[31m"
YEL="\e[33m"
BLU="\e[34m"
WHI="\e[97m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

# ==========================
# VARIAVEIS DE EXECUCAO
# ==========================
RUN_ID="$(date +%Y%m%d%H%M%S)"
DATE_STAMP="$(date +%Y%m%d)"
LOG_FILE="/root/blue3_start_${RUN_ID}.log"
BACKUP_DIR="/root/blue3_start_${RUN_ID}"

# ==========================
# VARIAVEIS DE AJUSTE RAPIDO
# ==========================
REQUIRED_DEBIAN_MAJOR="${REQUIRED_DEBIAN_MAJOR:-11}"
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-b3.local}"
DEFAULT_SSH_PORT="${DEFAULT_SSH_PORT:-22}"
DEFAULT_LOGIN_GRACE="${DEFAULT_LOGIN_GRACE:-30}"
DEFAULT_ROOT_IPS="${DEFAULT_ROOT_IPS:-100.64.66.0/24,170.233.230.254,170.233.230.222}"
DEFAULT_ZABBIX_SERVER="${DEFAULT_ZABBIX_SERVER:-100.64.66.8}"
ZABBIX_RELEASE_URL="${ZABBIX_RELEASE_URL:-}"
UPDATE_REPO_OWNER="${UPDATE_REPO_OWNER:-samirhvbr}"
UPDATE_REPO_NAME="${UPDATE_REPO_NAME:-Linux-Start}"
UPDATE_REPO_BRANCH="${UPDATE_REPO_BRANCH:-master}"

BASIC_PACKAGES=(
	zip
	fail2ban
	iptables
	w3m
	unzip
	net-tools
	bash-completion
	traceroute
	grc
	fzf
	htop
	iotop
	iftop
	whois
	tree
	mtr-tiny
	locate
	curl
	python3
)

log_raw() {
	printf '%s\n' "$*" >> "$LOG_FILE"
}

info() {
	printf '%b[INFO]%b %s\n' "$GREEN" "$ENDCOLOR" "$*"
	log_raw "[INFO] $*"
}

warn() {
	printf '%b[WARN]%b %s\n' "$YEL" "$ENDCOLOR" "$*" >&2
	log_raw "[WARN] $*"
}

error() {
	printf '%b[ERRO]%b %s\n' "$RED" "$ENDCOLOR" "$*" >&2
	log_raw "[ERRO] $*"
}

divider() {
	printf '%b----------------------------------------------------------------------------------------------------%b\n' "$WHI" "$ENDCOLOR"
}

print_step() {
	printf ' >> %-74s' "$1"
}

run_step() {
	local description="$1"
	shift

	print_step "$description"
	if "$@" >> "$LOG_FILE" 2>&1; then
		printf '%b [ OK ] %b\n' "$YEL" "$ENDCOLOR"
	else
		printf '%b [ERRO] %b\n' "$RED" "$ENDCOLOR"
		error "Falha em: $description. Consulte $LOG_FILE"
		return 1
	fi
}

prompt_default() {
	local label="$1"
	local default_value="$2"
	local answer

	read -r -p "$label [$default_value]: " answer
	printf '%s' "${answer:-$default_value}"
}

confirm() {
	local label="$1"
	local default_answer="${2:-N}"
	local answer

	read -r -p "$label ($( [[ "$default_answer" =~ ^[SsYy]$ ]] && printf 'S/n' || printf 's/N' )) " answer
	answer="${answer:-$default_answer}"

	[[ "$answer" =~ ^[SsYy]$ ]]
}

backup_file() {
	local target="$1"
	local relative_path

	[[ -e "$target" ]] || return 0

	relative_path="${target#/}"
	mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
	cp -a "$target" "$BACKUP_DIR/$relative_path"
}

restore_backup() {
	local target="$1"
	local relative_path

	relative_path="${target#/}"
	[[ -e "$BACKUP_DIR/$relative_path" ]] || return 1

	cp -a "$BACKUP_DIR/$relative_path" "$target"
}

load_local_version() {
	if [[ -f "$VERSION_FILE" ]]; then
		VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
	fi
}

load_env_file() {
	if [[ -f "$ENV_FILE" ]]; then
		# shellcheck disable=SC1090
		set -a
		source "$ENV_FILE"
		set +a
		info "Arquivo .env carregado: $ENV_FILE"
	else
		info "Arquivo .env nao encontrado. Usando valores padrao internos."
	fi
}

get_remote_version_url() {
	printf 'https://raw.githubusercontent.com/%s/%s/%s/VERSION' "$UPDATE_REPO_OWNER" "$UPDATE_REPO_NAME" "$UPDATE_REPO_BRANCH"
}

get_remote_archive_url() {
	printf 'https://github.com/%s/%s/archive/refs/heads/%s.tar.gz' "$UPDATE_REPO_OWNER" "$UPDATE_REPO_NAME" "$UPDATE_REPO_BRANCH"
}

fetch_remote_version() {
	wget -qO- "$(get_remote_version_url)" 2>> "$LOG_FILE" | tr -d '[:space:]'
}

version_greater_than() {
	local left="$1"
	local right="$2"
	[[ "$(printf '%s\n%s\n' "$left" "$right" | sort -V | tail -n1)" == "$left" && "$left" != "$right" ]]
}

check_for_updates() {
	local remote_version

	ensure_internet || return 1

	remote_version="$(fetch_remote_version || true)"
	if [[ -z "$remote_version" ]]; then
		warn "Nao foi possivel obter a versao remota em $(get_remote_version_url)"
		return 1
	fi

	printf 'Versao local : %s\n' "$VERSION"
	printf 'Versao remota: %s\n' "$remote_version"

	if version_greater_than "$remote_version" "$VERSION"; then
		info "Existe atualizacao disponivel no GitHub."
		return 0
	fi

	info "Projeto ja esta na versao mais recente conhecida."
	return 2
}

self_update_project() {
	local remote_version
	local archive_url
	local tmp_dir
	local archive_file
	local extracted_dir
	local project_backup_dir

	ensure_internet || return 1

	remote_version="$(fetch_remote_version || true)"
	if [[ -z "$remote_version" ]]; then
		error "Nao foi possivel consultar a versao remota. O repositorio ainda pode nao ter o arquivo VERSION publicado."
		return 1
	fi

	if ! version_greater_than "$remote_version" "$VERSION"; then
		info "Nenhuma atualizacao disponivel. Local: $VERSION | Remota: $remote_version"
		return 0
	fi

	printf 'Versao local : %s\n' "$VERSION"
	printf 'Versao remota: %s\n' "$remote_version"
	if ! confirm "Deseja baixar e aplicar esta atualizacao agora?" "S"; then
		warn "Atualizacao cancelada pelo operador."
		return 0
	fi

	archive_url="$(get_remote_archive_url)"
	tmp_dir="$(mktemp -d)"
	archive_file="$tmp_dir/${UPDATE_REPO_NAME}.tar.gz"
	project_backup_dir="$BACKUP_DIR/project_self_update"

	run_step "Baixando pacote do projeto no GitHub" wget -O "$archive_file" "$archive_url" || {
		rm -rf "$tmp_dir"
		return 1
	}

	run_step "Extraindo pacote de atualizacao" tar -xzf "$archive_file" -C "$tmp_dir" || {
		rm -rf "$tmp_dir"
		return 1
	}

	extracted_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
	if [[ -z "$extracted_dir" ]]; then
		rm -rf "$tmp_dir"
		error "Nao foi possivel localizar o conteudo extraido da atualizacao."
		return 1
	fi

	if [[ ! -f "$extracted_dir/VERSION" || ! -f "$extracted_dir/script.sh" ]]; then
		rm -rf "$tmp_dir"
		error "Pacote remoto nao contem a estrutura minima esperada."
		return 1
	fi

	mkdir -p "$project_backup_dir"
	cp -a "$SCRIPT_DIR/." "$project_backup_dir/"
	cp -a "$extracted_dir/." "$SCRIPT_DIR/"
	chmod +x "$SCRIPT_DIR/script.sh"
	rm -rf "$tmp_dir"

	info "Projeto atualizado para a versao $remote_version"
	info "Backup do projeto anterior salvo em $project_backup_dir"
	info "Reiniciando o script atualizado..."
	exec bash "$SCRIPT_DIR/script.sh"
}

require_files() {
	local file_path
	local missing=()

	for file_path in "$@"; do
		if [[ ! -f "$file_path" ]]; then
			missing+=("$file_path")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		error "Arquivos obrigatorios ausentes: ${missing[*]}"
		exit 1
	fi
}

copy_template() {
	local template_rel="$1"
	local destination="$2"
	local source_file="$TEMPLATE_DIR/$template_rel"

	if [[ ! -f "$source_file" ]]; then
		error "Template nao encontrado: $source_file"
		return 1
	fi

	cp "$source_file" "$destination"
}

render_template() {
	local template_rel="$1"
	local destination="$2"
	local source_file="$TEMPLATE_DIR/$template_rel"
	local key
	local value
	local escaped

	shift 2

	if [[ ! -f "$source_file" ]]; then
		error "Template nao encontrado: $source_file"
		return 1
	fi

	cp "$source_file" "$destination"

	while [[ $# -gt 1 ]]; do
		key="$1"
		value="$2"
		shift 2
		escaped="$(printf '%s' "$value" | sed -e 's/[\/&]/\\&/g')"
		sed -i "s|{{${key}}}|$escaped|g" "$destination"
	done
}

require_root() {
	if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
		error "Este script precisa ser executado como root."
		exit 1
	fi
}

require_debian() {
	local debian_major

	if [[ ! -r /etc/os-release ]]; then
		error "Nao foi possivel identificar o sistema operacional."
		exit 1
	fi

	# shellcheck disable=SC1091
	source /etc/os-release

	if [[ "${ID:-}" != "debian" ]]; then
		error "Este script foi preparado para Debian. Sistema detectado: ${ID:-desconhecido}."
		exit 1
	fi

	debian_major="${VERSION_ID%%.*}"
	if [[ -z "$debian_major" || "$debian_major" -lt "$REQUIRED_DEBIAN_MAJOR" ]]; then
		error "Debian ${REQUIRED_DEBIAN_MAJOR} ou superior e obrigatorio. Versao detectada: ${VERSION_ID:-desconhecida}."
		exit 1
	fi
}

require_commands() {
	local command_name
	local missing=()

	for command_name in "$@"; do
		if ! command -v "$command_name" > /dev/null 2>&1; then
			missing+=("$command_name")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		error "Comandos ausentes: ${missing[*]}"
		exit 1
	fi
}

ensure_internet() {
	if ping -c1 -W2 1.1.1.1 >> "$LOG_FILE" 2>&1; then
		return 0
	fi

	warn "Sem conectividade com a internet. Esta etapa pode falhar."
	return 1
}

get_default_iface() {
	ip route | awk '/default/ {print $5; exit}'
}

get_default_gateway_v4() {
	ip route | awk '/default/ {print $3; exit}'
}

get_primary_ipv4() {
	local iface="$1"
	ip -o -4 addr show dev "$iface" scope global | awk '{print $4; exit}'
}

get_primary_ipv6() {
	local iface="$1"
	ip -o -6 addr show dev "$iface" scope global | awk '{print $4; exit}'
}

get_dns_servers() {
	awk '/^nameserver/ {print $2}' /etc/resolv.conf | paste -sd' ' -
}

validate_ssh_config() {
	sshd -t >> "$LOG_FILE" 2>&1
}

init_environment() {
	mkdir -p "$BACKUP_DIR"
	touch "$LOG_FILE"
	log_raw "Inicio da execucao do $SCRIPT_NAME"
	log_raw "Versao: $VERSION"
	log_raw "Data stamp: $DATE_STAMP"
	log_raw "Backup dir: $BACKUP_DIR"
	log_raw "Log file: $LOG_FILE"
}

config_server() {
	local current_hostname
	local current_domain
	local current_fqdn
	local default_iface
	local current_ipv4
	local current_ipv6
	local hostname_value
	local domain_value
	local host_ipv4

	clear
	info "Configuracao inicial do servidor"
	divider

	current_hostname="$(hostname -s)"
	current_domain="$(hostname -d 2>>"$LOG_FILE" || true)"
	current_fqdn="$(hostname -f 2>>"$LOG_FILE" || true)"
	default_iface="$(get_default_iface 2>>"$LOG_FILE" || true)"
	current_ipv4="$( [[ -n "$default_iface" ]] && get_primary_ipv4 "$default_iface" 2>>"$LOG_FILE" || true )"
	current_ipv6="$( [[ -n "$default_iface" ]] && get_primary_ipv6 "$default_iface" 2>>"$LOG_FILE" || true )"

	printf 'Hostname atual : %s\n' "$current_hostname"
	printf 'Dominio atual  : %s\n' "${current_domain:-<vazio>}"
	printf 'FQDN atual     : %s\n' "${current_fqdn:-<vazio>}"
	printf 'Interface      : %s\n' "${default_iface:-<nao detectada>}"
	printf 'IPv4 atual     : %s\n' "${current_ipv4:-<nao detectado>}"
	printf 'IPv6 atual     : %s\n' "${current_ipv6:-<nao detectado>}"
	divider

	hostname_value="$(prompt_default "Qual o hostname do servidor?" "$current_hostname")"
	if [[ "$hostname_value" != "$current_hostname" ]]; then
		run_step "Alterando hostname" hostnamectl set-hostname "$hostname_value" || return 1
		current_hostname="$hostname_value"
	else
		info "Hostname mantido: $current_hostname"
	fi

	domain_value="$(prompt_default "Qual o dominio do servidor?" "${current_domain:-$DEFAULT_DOMAIN}")"

	if confirm "Deseja reescrever /etc/hosts com hostname e dominio atuais?" "S"; then
		backup_file /etc/hosts
		host_ipv4="${current_ipv4%%/*}"
		host_ipv4="${host_ipv4:-127.0.1.1}"

		cat > /etc/hosts <<EOF
127.0.0.1       localhost
$host_ipv4      ${current_hostname}.${domain_value} ${current_hostname}

# The following lines are desirable for IPv6 capable hosts
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF
		info "/etc/hosts atualizado. Backup em $BACKUP_DIR"
	fi

	if confirm "Deseja reconfigurar a interface de rede?" "N"; then
		change_ip "$current_hostname" "$domain_value" "$default_iface" "$current_ipv4" "$current_ipv6" || return 1
	fi

	divider
}

change_ip() {
	local hostname_value="$1"
	local domain_value="$2"
	local current_iface="$3"
	local current_ipv4="$4"
	local current_ipv6="$5"
	local iface
	local ipv4_ip
	local ipv4_mask
	local ipv4_gateway
	local dns_servers
	local enable_ipv6
	local ipv6_ip
	local ipv6_mask
	local ipv6_gateway
	local current_ipv4_ip
	local current_ipv4_mask
	local current_ipv6_ip
	local current_ipv6_mask
	local default_dns

	current_ipv4_ip="${current_ipv4%%/*}"
	current_ipv4_mask="${current_ipv4##*/}"
	[[ "$current_ipv4_ip" == "$current_ipv4" ]] && current_ipv4_mask="24"

	current_ipv6_ip="${current_ipv6%%/*}"
	current_ipv6_mask="${current_ipv6##*/}"
	[[ "$current_ipv6_ip" == "$current_ipv6" ]] && current_ipv6_mask="64"

	default_dns="$(get_dns_servers 2>>"$LOG_FILE" || true)"

	iface="$(prompt_default "Qual a interface da placa de rede?" "${current_iface:-eth0}")"
	ipv4_ip="$(prompt_default "Qual o IPv4 da interface ${iface}?" "${current_ipv4_ip:-100.64.66.88}")"
	ipv4_mask="$(prompt_default "Qual a mascara do IPv4 (CIDR)?" "${current_ipv4_mask:-24}")"
	ipv4_gateway="$(prompt_default "Qual o gateway do IPv4?" "$(get_default_gateway_v4 2>>"$LOG_FILE" || true)")"
	dns_servers="$(prompt_default "Quais os servidores DNS (separados por espaco)?" "${default_dns:-1.1.1.1 8.8.8.8}")"

	if confirm "Deseja configurar IPv6?" "N"; then
		enable_ipv6="1"
		ipv6_ip="$(prompt_default "Qual o IPv6 da interface ${iface}?" "${current_ipv6_ip:-2804:2c24:dc:1::2}")"
		ipv6_mask="$(prompt_default "Qual a mascara do IPv6 (CIDR)?" "${current_ipv6_mask:-64}")"
		ipv6_gateway="$(prompt_default "Qual o gateway do IPv6?" "")"
	else
		enable_ipv6="0"
		ipv6_ip=""
		ipv6_mask=""
		ipv6_gateway=""
	fi

	backup_file /etc/network/interfaces

	cat > /etc/network/interfaces <<EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-hotplug ${iface}
iface ${iface} inet static
	address ${ipv4_ip}/${ipv4_mask}
	gateway ${ipv4_gateway}
	dns-nameservers ${dns_servers}
	dns-search ${domain_value}
EOF

	if [[ "$enable_ipv6" == "1" ]]; then
		cat >> /etc/network/interfaces <<EOF

iface ${iface} inet6 static
	address ${ipv6_ip}/${ipv6_mask}
	gateway ${ipv6_gateway}
EOF
	fi

	backup_file /etc/hosts
	cat > /etc/hosts <<EOF
127.0.0.1       localhost
${ipv4_ip}      ${hostname_value}.${domain_value} ${hostname_value}

# The following lines are desirable for IPv6 capable hosts
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

	warn "Rede reconfigurada em arquivo. Revise /etc/network/interfaces antes de reiniciar o servico de networking."
	info "Backups salvos em $BACKUP_DIR"
}

install_update_upgrade() {
	ensure_internet || return 1

	export DEBIAN_FRONTEND=noninteractive

	run_step "Atualizando indices do APT" apt update || return 1
	run_step "Executando upgrade do sistema" apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade || return 1
	run_step "Limpando cache do APT" apt clean || return 1
	run_step "Removendo pacotes obsoletos" apt autoremove -y || return 1
	divider
}

install_appbasic() {
	ensure_internet || return 1
	export DEBIAN_FRONTEND=noninteractive

	run_step "Instalando aplicativos basicos" apt install -y "${BASIC_PACKAGES[@]}" || return 1
	divider
}

banner_blue3() {
	backup_file /etc/motd
	backup_file /etc/update-motd.d/10-uname
	backup_file /etc/update-motd.d/20-blue3

	: > /etc/motd

	copy_template "banner/10-uname.tpl" /etc/update-motd.d/10-uname || return 1
	copy_template "banner/20-blue3.tpl" /etc/update-motd.d/20-blue3 || return 1

	chmod 755 /etc/update-motd.d/10-uname /etc/update-motd.d/20-blue3
	info "Banner BLUE3 aplicado. Backups salvos em $BACKUP_DIR"
	divider
}

config_ssh() {
	local ssh_port
	local login_grace
	local allowed_ips

	backup_file /etc/ssh/sshd_config.d/blue3-hardening.conf
	backup_file /etc/ssh/sshd_config.d/blue3-root-ipath.conf
	backup_file /etc/ssh/sshd_config.d/rhosts.conf

	mkdir -p /etc/ssh/sshd_config.d

	ssh_port="$(prompt_default "Qual a porta do SSH?" "$DEFAULT_SSH_PORT")"
	login_grace="$(prompt_default "Qual o tempo para digitar a senha (segundos)?" "$DEFAULT_LOGIN_GRACE")"
	allowed_ips="$(prompt_default "Quais IPs autorizados a logar como root (separados por virgula)?" "$DEFAULT_ROOT_IPS")"

	render_template "ssh/blue3-hardening.conf.tpl" /etc/ssh/sshd_config.d/blue3-hardening.conf \
		SSH_PORT "$ssh_port" \
		LOGIN_GRACE "$login_grace" || return 1

	render_template "ssh/blue3-root-ipath.conf.tpl" /etc/ssh/sshd_config.d/blue3-root-ipath.conf \
		ALLOWED_ROOT_IPS "$allowed_ips" || return 1

	copy_template "ssh/rhosts.conf.tpl" /etc/ssh/sshd_config.d/rhosts.conf || return 1

	if ! validate_ssh_config; then
		warn "Configuracao SSH invalida. Restaurando arquivos anteriores."
		restore_backup /etc/ssh/sshd_config.d/blue3-hardening.conf || rm -f /etc/ssh/sshd_config.d/blue3-hardening.conf
		restore_backup /etc/ssh/sshd_config.d/blue3-root-ipath.conf || rm -f /etc/ssh/sshd_config.d/blue3-root-ipath.conf
		restore_backup /etc/ssh/sshd_config.d/rhosts.conf || rm -f /etc/ssh/sshd_config.d/rhosts.conf
		return 1
	fi

	run_step "Reiniciando servico SSH" systemctl restart ssh || return 1
	info "SSH configurado com validacao previa em sshd -t"
	divider
}

install_bashrc() {
	backup_file /root/.bashrc

	copy_template "bash/root.bashrc.tpl" /root/.bashrc || return 1

	info ".bashrc do root atualizado. Backup salvo em $BACKUP_DIR"
	divider
}

install_zabbix() {
	local hostname_short
	local zabbix_server
	local zabbix_tmp_deb

	ensure_internet || return 1
	export DEBIAN_FRONTEND=noninteractive

	run_step "Removendo Zabbix Agent antigo" apt purge -y zabbix-agent zabbix-agent2 || true
	run_step "Limpando dependencias obsoletas" apt autoremove -y || return 1
	run_step "Atualizando indices do APT" apt update || return 1

	if apt-cache show zabbix-agent >> "$LOG_FILE" 2>&1; then
		run_step "Instalando Zabbix Agent pelos repositorios atuais" apt install -y zabbix-agent || return 1
	else
		if [[ -z "$ZABBIX_RELEASE_URL" ]]; then
			error "Pacote zabbix-agent indisponivel nos repositorios atuais e ZABBIX_RELEASE_URL nao foi definido."
			return 1
		fi

		zabbix_tmp_deb="/root/zabbix-release_${RUN_ID}.deb"
		run_step "Baixando repositorio do Zabbix" wget -O "$zabbix_tmp_deb" "$ZABBIX_RELEASE_URL" || return 1
		run_step "Instalando repositorio do Zabbix" dpkg -i "$zabbix_tmp_deb" || return 1
		run_step "Atualizando indices do APT apos repositorio Zabbix" apt update || return 1
		run_step "Instalando Zabbix Agent" apt install -y zabbix-agent || return 1
	fi

	hostname_short="$(hostname -s)"
	zabbix_server="$(prompt_default "Qual o IP do servidor Zabbix?" "$DEFAULT_ZABBIX_SERVER")"

	backup_file /etc/zabbix/zabbix_agentd.d/blue3.conf
	mkdir -p /etc/zabbix/zabbix_agentd.d
	cat > /etc/zabbix/zabbix_agentd.d/blue3.conf <<EOF
Server=${zabbix_server}
ServerActive=${zabbix_server}
Hostname=${hostname_short}
EOF

	backup_file /etc/zabbix/zabbix_agentd.d/userparameter_fail2ban.conf
	cat > /etc/zabbix/zabbix_agentd.d/userparameter_fail2ban.conf <<'EOF'
UserParameter=fail2ban.status[*],fail2ban-client status '$1' | awk -F': ' '/Currently banned/ {print $2}'
UserParameter=fail2ban.statustotal[*],fail2ban-client status '$1' | awk -F': ' '/Total banned/ {print $2}'
UserParameter=fail2ban.discovery,fail2ban-client status | sed -e 's/^.*:\W\+//' -e 's/\(\([[:alnum:]]\|-\)\+\)/{"{#JAIL}":"\1"}/g' -e 's/.*/{"data":[\0]}/'
EOF

	if systemctl list-unit-files fail2ban.service >> "$LOG_FILE" 2>&1; then
		getent group fail2ban > /dev/null 2>&1 || groupadd --system fail2ban >> "$LOG_FILE" 2>&1
		usermod -a -G fail2ban zabbix >> "$LOG_FILE" 2>&1 || true

		mkdir -p /etc/systemd/system/fail2ban.service.d
		backup_file /etc/systemd/system/fail2ban.service.d/override.conf
		cat > /etc/systemd/system/fail2ban.service.d/override.conf <<'EOF'
[Service]
ExecStartPost=/bin/sh -c 'while [ ! -S /run/fail2ban/fail2ban.sock ]; do sleep 1; done'
ExecStartPost=/bin/chgrp fail2ban /run/fail2ban/fail2ban.sock
ExecStartPost=/bin/chmod g+rw /run/fail2ban/fail2ban.sock
EOF

		run_step "Recarregando units do systemd" systemctl daemon-reload || return 1
		run_step "Reiniciando fail2ban" systemctl restart fail2ban || return 1
	else
		warn "Fail2ban nao esta instalado. A integracao de socket com Zabbix foi ignorada."
	fi

	run_step "Reiniciando Zabbix Agent" systemctl restart zabbix-agent || return 1
	divider
}

out_here() {
	divider
	info "Execucao finalizada."
	info "Versao atual do projeto: $VERSION"
	info "Log: $LOG_FILE"
	info "Backups: $BACKUP_DIR"
	exit 0
}

show_header() {
	clear
	cat <<EOF

#
# OBS:
# Script deve ser executado apenas em Linux Debian ${REQUIRED_DEBIAN_MAJOR} ou posterior.
# Metodo de banimento com Fail2Ban: route (blackhole)
# Script by Samir Hanna Verza
# Versao ${VERSION}
# Update repo: ${UPDATE_REPO_OWNER}/${UPDATE_REPO_NAME}:${UPDATE_REPO_BRANCH}
#

EOF
}

run_menu_option() {
	local status=0

	"$@" || status=$?
	if [[ "$status" -ne 0 ]]; then
		warn "A etapa terminou com erro. Consulte $LOG_FILE"
		divider
	fi
}

main_menu() {
	local numchoice

	while true; do
		show_header
		echo -e "${BLU}
# MENU
${ENDCOLOR}"
		cat <<'EOF'
1. Config server
2. Update e upgrade do sistema
3. Instalar aplicativos basicos
4. Configurar banner de inicializacao
5. Aplicar .bashrc BLUE3 para root
6. Configurar SSH
U. Verificar e aplicar atualizacao do projeto
Z. Instalar Zabbix Agent
0. Sair
EOF
		echo
		read -r -p "Selecione a opcao desejada: " numchoice

		case "$numchoice" in
			1) run_menu_option config_server ;;
			2) run_menu_option install_update_upgrade ;;
			3) run_menu_option install_appbasic ;;
			4) run_menu_option banner_blue3 ;;
			5) run_menu_option install_bashrc ;;
			6) run_menu_option config_ssh ;;
			U|u) run_menu_option self_update_project ;;
			Z|z) run_menu_option install_zabbix ;;
			0|x|X|q|Q|exit|EXIT|Exit|quit|QUIT|Quit) out_here ;;
			*) warn "Opcao invalida." ;;
		esac

		read -r -p "Pressione Enter para voltar ao menu..." _
	done
}

trap 'error "Falha inesperada na linha ${BASH_LINENO[0]}. Consulte $LOG_FILE"' ERR

require_root
load_local_version
load_env_file
require_debian
require_commands apt awk cp cut date find getent grep head hostname hostnamectl ip mkdir mktemp mv ping sed sshd systemctl tar tee tr wget
require_files \
	"$VERSION_FILE" \
	"$TEMPLATE_DIR/banner/10-uname.tpl" \
	"$TEMPLATE_DIR/banner/20-blue3.tpl" \
	"$TEMPLATE_DIR/bash/root.bashrc.tpl" \
	"$TEMPLATE_DIR/ssh/blue3-hardening.conf.tpl" \
	"$TEMPLATE_DIR/ssh/blue3-root-ipath.conf.tpl" \
	"$TEMPLATE_DIR/ssh/rhosts.conf.tpl"
init_environment
main_menu
