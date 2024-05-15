#!/bin/bash

#
#
#
#  * Autor: Samir Hanna Verza
#  * Criado: 20/01/2023
#  * 
#  * Ult. Atualizacao: 
#  * Data: 14/05/2024
#
#
#
VERSAO=221

#
# CARREGAR VARIAVEIS DE AMBIENTE
#
Hostname=$(hostname -s)
Domain=$(hostname -d)
Fqdn=$(hostname -f)
Iplocal=`hostname -i`
Ipv4=$(ip addr show |grep inet |awk '{print $2}' |sed -n -e 3,3p)
Ipv6=$(ip addr show |grep inet |awk '{print $2}' |sed -n -e 4,4p)

#
# CONEXAO COM O BANCO DE DADOS
#
DBhost=100.64.66.211
DBuser=b3server
DBpass=Blue3DBx2623y
DBdatabase=server
SQL_QUERY="SELECT script_version FROM vm WHERE hostname = '$Hostname' AND ativo = '1' LIMIT 1"
result=$(mysql -h "$DBhost" -u "$DBuser" -p"$DBpass" -D "$DBdatabase" -e "$SQL_QUERY")
if [ $? -ne 0 ]; then
	echo "Erro ao conectar com o banco de dados!"
	exit 1
fi
#
# VERIFICANDO VERSAO DO SCRIPT
#
if [ "$result" != "$VERSAO" ]; then
	#
	# UPDATE DO SCRIPT
	#
	echo "Versão do script é diferente da versão do banco de dados"
	wget https://files.b3.rs/blue3/scgit -O /root/scgit.sh
	if [ ! -s /root/scgit.sh ]; then
		echo "O arquivo /root/scgit.sh não existe ou está vazio."
		echo "ERROR: 1"
		exit 1
	fi
	chmod +x /root/scgit.sh
	echo "Script Atualizado!"
	SQL_QUERY_a="INSERT INTO script_log_update (hostname,domain,ipv4_local,ipv6_local,script_version_old,script_version) VALUES ('$Hostname','$Domain','$Ipv4','$Ipv6','$VERSAO','$result')"
	result_a=$(mysql -h "$DBhost" -u "$DBuser" -p"$DBpass" -D "$DBdatabase" -e "$SQL_QUERY_a")
	if [ $? -ne 0 ]; then
		echo "Erro ao conectar com o banco de dados! (2)"
		exit 1
	fi
	source /root/scgit.sh
	if [ $? -ne 0 ]; then
		echo "Script externo falhou. Saindo do script principal."
		exit 1
	fi
	exit 0
fi


#
# VARIAVEIS DE STATUS DO SERVIDOR
#
total_memory=$(free -m | awk 'NR==2{print $2}')
free_memory=$(free -m | awk 'NR==2{print $4}')
cache_memory=$(free -m | awk 'NR==2{print $6}')
swap_total=$(free -m | awk 'NR==2{print $2}')
swap_usage=$(free -m | awk 'NR==3{print $3}')

cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
cpu_load=$(top -bn1 | grep "load average:" | awk '{print $12 $13 $14}')
cpu_jumps=$(top -bn1 | grep "load average:" | awk '{print $12 $13 $14}' | awk -F, '{print $1}')

# VERIFICANDO ESPAÇO EM DISCO UTILIZADO
root_disk_usage=$(df -h | awk '/\/$/ {print $5}' |tr -d '%')
var_disk_usage=$(df -h | awk '/\/var$/' | awk '{print $5}' |tr -d '%')
log_disk_usage=$(df -h | awk '/\/var\/log$/' | awk '{print $5}' |tr -d '%')
srv_disk_usage=$(df -h | awk '/\/srv$/' | awk '{print $5}' |tr -d '%')
# VERIFICAR AS PORTAS DE REDE EM QUAL VELOCIDADE ESTAO CONECTADAS
# VERIFICAR SE O PACOTE ETHTOOL ESTA INSTALADO
if [ ! -f /usr/sbin/ethtool ]; then
	apt install ethtool -y
fi
rede_um=$(ethtool eth0 | grep Speed | awk '{print $2}' |tr -d 'Mb/s')
# VERIFICAR SE EXISTE A ETH1
if [ -f /sys/class/net/eth1 ]; then
		rede_dois=$(ethtool eth1 | grep Speed | awk '{print $2}' |tr -d 'Mb/s')
	else
		rede_dois=0
fi

# LER OS LOGS CRITICOS ULTIMOS 10 USANDO O JOURNALCTL
logs_crit=$(journalctl -p crit -n 10 --no-pager | tail -n +2)
logs=$(journalctl -p 1..3 -n 10 --no-pager | tail -n +2)


# INSERINDO NO BANCO DE DADOS
SQL_QUERY_b="INSERT INTO vm_status (hostname,ipv4_local,total_memory,free_memory,cache_memory,swap_total,swap_usage,cpu_usage,cpu_load,cpu_jumps,root_disk_usage,var_disk_usage,log_disk_usage,srv_disk_usage,eth0_vel,eth1_vel) VALUES ('$Hostname','$Ipv4','$total_memory','$free_memory','$cache_memory','$swap_total','$swap_usage','$cpu_usage','$cpu_load','$cpu_jumps','$root_disk_usage','$var_disk_usage','$log_disk_usage','$srv_disk_usage','$rede_um','$rede_dois')"
result_b=$(mysql -h "$DBhost" -u "$DBuser" -p"$DBpass" -D "$DBdatabase" -e "$SQL_QUERY_b")
if [ $? -ne 0 ]; then
	echo "Erro ao conectar com o banco de dados! (3)"
	exit 1
fi

SQL_QUERY_c="INSERT INTO vm_status_log (hostname,ipv4_local,log) VALUES ('$Hostname','$Ipv4','$logs')"
result_c=$(mysql -h "$DBhost" -u "$DBuser" -p"$DBpass" -D "$DBdatabase" -e "$SQL_QUERY_c")
if [ $? -ne 0 ]; then
	echo "Erro ao conectar com o banco de dados! (4)"
	exit 1
fi

SQL_QUERY_d="INSERT INTO vm_status_logcrit (hostname,ipv4_local,log) VALUES ('$Hostname','$Ipv4','$logs_crit')"
result_d=$(mysql -h "$DBhost" -u "$DBuser" -p"$DBpass" -D "$DBdatabase" -e "$SQL_QUERY_d")
if [ $? -ne 0 ]; then
	echo "Erro ao conectar com o banco de dados! (5)"
	exit 1
fi



#
# VERIFICANDO SE PRECISA ATUALIZAR O OS
#
if [ "${result[1]}" == "1" ]; then
	echo "Precisa atualizar o script"
else
	echo "Não precisa atualizar o script"
fi



exit




#
# RETORNANDO A VERSAO
#
if [ "$1" == "--version" ]; then
	echo "${VERSION}"
	exit
fi







#
# UPGRADE DEBIAN OS
#
if [ "$1" == "--upgrade" ]; then
	# Verificando se é Debian
	if [ ! -f /etc/debian_version ]; then
		echo "Este script é para Debian!"
		exit
	fi
	#apt update --allow-unauthenticated --allow-insecure-repositories
	apt update
	apt -y -o Dpkg::Options::="--force-confold" upgrade
	apt -y -o Dpkg::Options::="--force-confold" dist-upgrade
	apt autoremove -y
	apt autoclean -y

	echo "Sistema Atualizado!"
	exit
fi





#
# VARIAVEIS DE CORES
#
RED="\e[31m"
YEL="\e[33m"
BLU="\e[34m"
WHI="\e[97m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"



#
# CRIANDO PASTA DOS BACKUPS E LOG
#
DATE=$(date +%Y%m%d)
DATE2=$(date +%Y%m%d%s)
LOG='/root/shv_script_${DATE2}.log'
DIR=/root/$DATE2
#if [ -d "/root/${DATE2}/" ]; then
    mkdir $DIR
#else
	#mkdir $DIR
#fi



# apt install ntp
# server 100.64.66.230 prefer iburst



#
# CONFIG SERVER
#
config_server (){
	clear
	echo ;echo 
	echo "VAMOS EFETUAR A CONFIGURACAO INICIAL DO SERVIDOR"
	echo ;echo ;echo 
	
	hostname=$(hostname -s) >> $LOG 2>&1
	domain=$(hostname -d) >> $LOG 2>&1
	fqdn=$(hostname -f) >> $LOG 2>&1
	iplocal=`hostname -i` >> $LOG 2>&1
	ipv4=$(ip addr show |grep inet |awk '{print $2}' |sed -n -e 3,3p) >> $LOG 2>&1
	ipv6=$(ip addr show |grep inet |awk '{print $2}' |sed -n -e 4,4p) >> $LOG 2>&1

	
	read -p "Qual o hostname do servidor? (${hostname})? " choice
	if [ -z $choice ]; then
		echo "OK, nada a ser feito!"
	else
		hostnamectl set-hostname $choice
		echo "hostname alterado"
	fi

	changedomain (){
		read -p "Qual o dominio para este servidor ? " DOMAIN
		echo "127.0.0.1       localhost" > /etc/hosts
		echo "${ipv4}    ${hostname}.${DOMAIN}    git" >> /etc/hosts
		echo "" >> /etc/hosts
		echo "# The following lines are desirable for IPv6 capable hosts" >> /etc/hosts
		echo "::1     localhost ip6-localhost ip6-loopback" >> /etc/hosts
		echo "ff02::1 ip6-allnodes" >> /etc/hosts
		echo "ff02::2 ip6-allrouters" >> /etc/hosts
		sed -i "s/`hostname -d`/${DOMAIN}/g" /etc/network/interfaces
	}
	#echo ;echo ;read -p "Esta correto o dominio deste servidor (${domain}) (S/n) ? " DOMAIN
	#case "$DOMAIN" in
	#	s|S|y|Y ) echo "OK, nada a ser feito!" ;;
	#	n|N ) changedomain ;;
	#	* ) echo "OK, nada a ser feito!" ;;
	#esac

	
	changeip (){
		read -p "Qual a interface da placa de rede a ser ajustada (ex: eth0)? " NETI
		read -p "Qual o IPv4 da porta (${NETI})? " IPV4
		read -p "Qual a mascara do IPv4 (${IPV4}) (ex: 24) ? " MASK4
		read -p "Qual o gateway do IPV4 (${IPV4}) ? " GW4

		read -p "Vamos configurar IPv6 neste servidor (S/n) ? " ipv6s
		if [[ $ipv6s == [sS] ]]; then
			ipv6s=1
			read -p "Qual o IPv6 da porta ${NETI}? " IPV6
			read -p "Qual a mascara do IPv6 (${IPV6}) (ex: 64) ? " MASK6
			read -p "Qual o gateway do IPV6 (${IPV6}) ? " GW6
		else
			ipv6s=0
		fi

		read -p "Qual os servidores DNS (separados por espaco) ? " DNSs
		#read -p "Qual o dominio para este servidor (${domain}) ? " DOMAIN
		

cat <<\EOF >/etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
source /etc/network/interfaces.d/*
# The loopback network interface
auto lo
iface lo inet loopback
# The primary network interface
EOF

	echo "allow-hotplug ${NETI}" >> /etc/network/interfaces
	echo "iface ${NETI} inet static" >> /etc/network/interfaces
	echo "	address ${IPV4}/${MASK4}" >> /etc/network/interfaces
	echo "	gateway ${GW4}" >> /etc/network/interfaces
	echo "	dns-nameserver ${DNSs}" >> /etc/network/interfaces
	echo "	dns-search ${domain}" >> /etc/network/interfaces
	echo "" >> /etc/network/interfaces
	if [ "$ipv6s" -eq 1 ]; then
		echo "iface ${NETI} inet6 static" >> /etc/network/interfaces
		echo "	pre-up modprobe ipv6" >> /etc/network/interfaces
		echo "	address ${IPV6}" >> /etc/network/interfaces
		echo "	netmask ${MASK6}" >> /etc/network/interfaces
		echo "	gateway ${GW6}" >> /etc/network/interfaces
	fi


	echo ;echo ;echo "Para que as atualizacoes tenham efeito, eh preciso reiniciar o servico de network"; echo ;echo ;
	echo -n " >> Reconfigurando a network................................................"
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ;echo 
	}

	echo ;echo ;read -p "O IPv4 local do servidor esta correto (${ipv4}) (S/n) ? " choice
	case "$choice" in
		s|S|y|Y ) echo "OK, nada a ser feito!";echo ;echo ; ;;
		n|N ) changeip ;;
		* ) echo "OK, nada a ser feito!";echo ;echo ; ;;
	esac
}







#
# Update e upgrade do sistem
#
install_update_upgrade () {
	echo ;echo 
	echo -n " >> Update do sistema......................................................."
	apt update --allow-unauthenticated >> $LOG 2>&1
	apt update --allow-insecure-repositories >> $LOG 2>&1
	apt update  >> $LOG 2>&1
	#apt update >> $LOG 2>&1
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo

	echo -n " >> Upgrade do sistema......................................................"
    apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade >> $LOG 2>&1
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo

	echo -n " >> Clear do sistema........................................................"
    apt clean >> $LOG 2>&1
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo

	echo -n " >> Autoremove do sistema..................................................."
    apt autoremove -y >> $LOG 2>&1
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ;echo ;echo -e "${WHI}----------------------------------------------------------------------------------------------------${ENDCOLOR}"; echo ; echo ; echo ; echo 
}



#
# CONTINUAR
# INSTALANDO APPS BASIC
#
install_appbasic (){ 
    echo ;echo 
    echo -n " >> Instalando apps basicos................................................."
    apt install zip openssh-server fail2ban iptables wget w3m vim gzip unzip xfsprogs btrfs-progs net-tools zstd bash-completion apt-transport-https traceroute grc fzf htop iotop iftop hdparm whois tree mtr-tiny locate curl python3 -y >> $LOG 2>&1
    sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ;echo ;echo -e "${WHI}----------------------------------------------------------------------------------------------------${ENDCOLOR}"; echo ; echo ; echo ; echo 
}



#
# BANNER BLUE3
#
banner_blue3 (){
    echo; echo 
    echo -n " >> Aplicando banne BLUE3..................................................."

	cat /etc/motd > $DIR/motd.$DATE2
	echo "" > /etc/motd

	cat /etc/update-motd.d/10-uname > $DIR/10-uname.$DATE2
	echo "#!/bin/bash" > /etc/update-motd.d/10-uname

cat <<\EOF >/etc/update-motd.d/20-blue3
#!/bin/bash

# pegando o uptime do servidor
upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
secs=$((${upSeconds}%60))
mins=$((${upSeconds}/60%60))
hours=$((${upSeconds}/3600%24))
days=$((${upSeconds}/86400))
UPTIME=`printf "%d days, %02dh%02dm%02ds" "$days" "$hours" "$mins" "$secs"`

# pegando o load averages dos proc
read one five fifteen rest < /proc/loadavg

# demora muito para ler o ip
# IP Addresses.......: `ip a | grep glo | awk '{print $2}' | head -1 | cut -f1 -d/`

# modelo de CPU
# cat /proc/cpuinfo |grep 'model name' |awk -F ":" '{print substr($2,2,300)}'
# cat /proc/cpuinfo |grep 'model name' |awk -F ":" '{print substr($2,2,300)}' |sed -n -e 1p

#echo -e "\033[93m"
#echo "IPs"
#ip addr show |grep inet |awk '{print $2}' |sed -n -e 3,8p

echo -e "
\033[34m
                                    BLUE3 INTERNET
 ____  _            ____            `date +"%A, %e %B %Y, %R:%S"`
|  _ \| |          |___ \\           `uname -srmo `$(tput setaf 1)
| |_) | |_   _  ___  __) |
|  _ <| | | | |/ _ \|__ <           Uptime.............: ${UPTIME}
| |_) | | |_| |  __/___) |          Memory.............: `cat /proc/meminfo |grep MemFree |awk {'print $2'}`kB (Free) / `cat /proc/meminfo | grep MemTotal | awk {'print $2'}`kB (Total)
|____/|_|\__,_|\___|____/           CPU Info...........: `cat /proc/cpuinfo |grep 'model name' |awk -F ":" '{print substr($2,2,300)}' |sed -n -e 1p`
                                    CPU Load...........: ${one}, ${five}, ${fifteen} (1, 5, 15 min)
                                    
\033[97m
"
#				    Running Processes..: `ps ax | wc -l | tr -d " "`
#                                   IP Addresses IPv4..: `ip addr show |grep inet |awk '{print $2}' |sed -n -e 3,3p`
#                                   IP Addresses.IPv6..: `ip addr show |grep inet |awk '{print $2}' |sed -n -e 4,4p`
#				    IP Addresses Pub...: `curl -s "https://ifconfig.me/ip"`
#
#				    Time Zone..........: `curl ipinfo.io/timezone`
#				    Local..............: `curl ipinfo.io/city`
#				    Organization.......: `curl -s "https://ipinfo.io/org" |awk '{print $2,$3}'`
#				    ASN................: `curl -s "https://ipinfo.io/org" |awk '{print $1}'`
#for i in {16..21} {21..16} ; do echo -en "\e[38;5;${i}m  B3  \e[0m" ; done ; echo
for i in {16..21} {21..16} ; do echo -en "\e[48;5;${i}m     \e[0m" ; done ; echo ; echo 
EOF
chmod 755 /etc/update-motd.d/20-blue3

	
	sed -i "s/#PrintLastLog yes/PrintLastLog no/g" /etc/ssh/sshd_config


    sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ; echo ;echo -e "${WHI}----------------------------------------------------------------------------------------------------${ENDCOLOR}"; echo ; echo ; echo ; echo 
}



#
# SSH MOD
#
config_ssh (){
	echo; echo 
	echo -n " >> Iniciando a personalizacao do SSH..................................................."
	echo ;echo 	

	PORTDEF=22
	read -p "Confirma a porta do SSH (${PORTDEF})? " choice
	if [ -z $choice ]; then
		sed -i "s/#Port 22/Port ${PORTDEF}/g" /etc/ssh/sshd_config
		echo 
	else
		sed -i "s/#Port 22/Port ${choice}/g" /etc/ssh/sshd_config
		echo 
	fi

	TPASSDEF=30
	read -p "Qual o tempo para digitar a senha (segundos) (${TPASSDEF})? " choice
	if [ -z $choice ]; then
		sed -i "s/#LoginGraceTime 2m/LoginGraceTime ${TPASSDEF}/g" /etc/ssh/sshd_config
		echo 
	else
		sed -i "s/#LoginGraceTime 2m/LoginGraceTime ${choice}/g" /etc/ssh/sshd_config
		echo 
	fi



	sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
	sed -i "/^#ListenAddress ::/a Protocol 2" /etc/ssh/sshd_config
	sed -i "s/#SyslogFacility AUTH/SyslogFacility AUTH/g" /etc/ssh/sshd_config
	sed -i "s/#LogLevel INFO/LogLevel INFO/g" /etc/ssh/sshd_config
	sed -i "s/#PrintLastLog yes/PrintLastLog no/g" /etc/ssh/sshd_config
	sed -i "s/#StrictModes yes/StrictModes yes/g" /etc/ssh/sshd_config
	sed -i "s/#PermitEmptyPasswords no/PermitEmptyPasswords no/g" /etc/ssh/sshd_config
	sed -i "s/#X11DisplayOffset 10/X11DisplayOffset 10/g" /etc/ssh/sshd_config
	sed -i "s/#PrintMotd no/PrintMotd no/g" /etc/ssh/sshd_config
	sed -i "s/#TCPKeepAlive yes/TCPKeepAlive yes/g" /etc/ssh/sshd_config

	mkdir -p /etc/ssh/sshd_config.d/
	echo "#Privilege Separation is turned on for security" > /etc/ssh/sshd_config.d/useprivilegeseparation.conf
	echo "UsePrivilegeSeparation yes" >> /etc/ssh/sshd_config.d/useprivilegeseparation.conf

	echo "# Lifetime and size of ephemeral version 1 server key" > /etc/ssh/sshd_config.d/keyregeneration.conf
	echo "KeyRegenerationInterval 3600" >> /etc/ssh/sshd_config.d/keyregeneration.conf
	echo "ServerKeyBits 1024" >> /etc/ssh/sshd_config.d/keyregeneration.conf

	
	IPAUTHDEF="100.64.66.0/24,170.233.230.254,170.233.230.222"
	read -p "Quais IPs autorizados a logar como root, separados por , (${IPAUTHDEF})? " choice
	if [ -z $choice ]; then
		IPAUTH=$IPAUTHDEF
	else
		IPAUTH=$choice
	fi
	echo "# IPs autorizados a logar como root!" > /etc/ssh/sshd_config.d/ipath.conf
	echo "Match Address ${IPAUTH}" >> /etc/ssh/sshd_config.d/ipath.conf
	echo "	PermitRootLogin yes" >> /etc/ssh/sshd_config.d/ipath.conf
	

cat <<\EOF >/etc/ssh/sshd_config.d/rhosts.conf
IgnoreRhosts yes
# For this to work you will also need host keys in /etc/ssh_known_hosts
RhostsRSAAuthentication no
# similar for protocol version 2
HostbasedAuthentication no
RSAAuthentication yes
PubkeyAuthentication yes
EOF


echo ;echo ;echo -n " >> Reiniciando servico SSH................................................."
systemctl restart ssh
echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ;echo ;echo 

	echo -n " >> Aplicando Mod SSH......................................................."
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ; echo ;echo -e "${WHI}----------------------------------------------------------------------------------------------------${ENDCOLOR}"; echo ; echo ; echo ; echo 
}






#
# INSTALL BASHRC
#
install_bashrc (){
	echo; echo ;echo -n " >> Aplicando banne BLUE3..................................................."
mv /root/.bashrc $DIR/bashrc_
touch /root/.bashrc

cat <<\EOF >/root/.bashrc
#
# CRIADO POR: SAMIR HANNA VERZA
# CRIADO EM: 20/05/2019
# ATUALIZADO: 20/05/2019
#
#
#
#OLD
# export PS1='\[\033[1;37m\]\t ${debian_chroot:+($debian_chroot)}\[\033[01;33m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[1;33m\]# \[\033[37m\]'
#NEW
#PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\$\[\033[00m\] '
# LAST
PS1='\[\033[1;37m\]\t ${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;33m\]\$\[\033[00m\] '

# ?
source /usr/share/doc/fzf/examples/key-bindings.bash
EOF

	echo "" >> /root/.bashrc
	echo "alias l='ls -alFh --color=auto'" >> /root/.bashrc
	echo "alias vi='vi -C -c \"set nocp\" -c \"syn on\"'" >> /root/.bashrc
	echo "alias ..='cd ..'" >> /root/.bashrc
	echo "alias ls='ls --color'" >> /root/.bashrc
	echo "alias lh=\"ls -aFh -lS --color | grep -v '^d'\"" >> /root/.bashrc

	echo "" >> /root/,bashrc
	echo "alias grep='grep --color'" >> /root/.bashrc
	echo "alias ip='ip -c'" >> /root/.bashrc
	echo "alias tail='grc tail'" >> /root/.bashrc
	echo "alias ping='grc ping'" >> /root/.bashrc
	echo "alias traceroute='grc traceroute'" >> /root/.bashrc
	echo "alias ps='grc ps'" >> /root/.bashrc
	echo "alias netstat='grc netstat'" >> /root/.bashrc
	echo "alias dig='grc dig'" >> /root/.bashrc
	echo "alias meuip='curl ifconfig.me; echo;'" >> /root/.bashrc
	echo "alias mv='mv -v'" >> /root/.bashrc




	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ; echo ;echo -e "${WHI}----------------------------------------------------------------------------------------------------${ENDCOLOR}"; echo ; echo ; echo ; echo 
}





#
# INSTALL ZABBIX AGENT
#
install_zabbix(){
	echo; echo ;echo -n " >> Instalando Zabbix Agent................................................."; echo ;echo 

	apt purge zabbix-agent -y >> $LOG 2>&1
	apt autoremove -y >> $LOG 2>&1

	hostname=`hostname -s` >> $LOG 2>&1
	ZBX_DEFAULT=100.64.66.8
	read -p "Qual o IP do Zabbix (${ZBX_DEFAULT})? " choice
	if [ -z $choice ]; then
		ZABBIX_SERVER=$ZBX_DEFAULT
	else
		ZABBIX_SERVER=$choice
	fi

	#wget https://repo.zabbix.com/zabbix/6.3/debian/pool/main/z/zabbix-release/zabbix-release_6.3-3+debian11_all.deb -O /root/zabbix.deb >> $LOG 2>&1
	wget https://repo.zabbix.com/zabbix/6.2/debian/pool/main/z/zabbix-release/zabbix-release_6.2-1%2Bdebian11_all.deb -O /root/zabbix.deb >> $LOG 2>&1
	dpkg -i /root/zabbix.deb >> $LOG 2>&1
	apt update >> $LOG 2>&1
	apt install zabbix-agent -y >> $LOG 2>&1
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo

	echo ;echo -n " >> Configurando Zabbix Agent..............................................."
	sed -i "s/Server=127.0.0.1/Server=${ZABBIX_SERVER}/g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/ServerActive=127.0.0.1/ServerActive=${ZABBIX_SERVER}/g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/Hostname=Zabbix server/Hostname=${hostname}/g" /etc/zabbix/zabbix_agentd.conf

# VERIFICAR SE FAIL2BAN JA INSTALADO
cat <<\EOF >/etc/zabbix/zabbix_agentd.d/userparameter_fail2ban.conf
UserParameter=fail2ban.status[*],fail2ban-client status '$1' | grep 'Currently banned:' | grep -E -o '[0-9]+'
UserParameter=fail2ban.statustotal[*],fail2ban-client status '$1' | grep 'Total banned:' | grep -E -o '[0-9]+'
UserParameter=fail2ban.discovery,fail2ban-client status | grep 'Jail list:' | sed -e 's/^.*:\W\+//' -e 's/\(\(\w\|-\)\+\)/{"{#JAIL}":"\1"}/g' -e 's/.*/{"data":[\0]}/'
EOF
	addgroup --group fail2ban  >> $LOG 2>&1
	usermod -a -G fail2ban zabbix  >> $LOG 2>&1
	chown root:fail2ban /var/run/fail2ban/fail2ban.sock >> $LOG 2>&1
	chmod g+rwx /var/run/fail2ban/fail2ban.sock >> $LOG 2>&1
	mkdir /var/lib/zabbix >> $LOG 2>&1
	chown zabbix:zabbix /var/lib/zabbix >> $LOG 2>&1
	mkdir /nonexistent >> $LOG 2>&1
	chown zabbix:zabbix /nonexistent >> $LOG 2>&1
	mkdir /etc/systemd/system/fail2ban.service.d >> $LOG 2>&1


cat <<\EOF >/etc/systemd/system/fail2ban.service.d/override.conf
[Service]
ExecStartPost=/bin/sh -c "while ! [ -S /run/fail2ban/fail2ban.sock ]; do sleep 1; done"
ExecStartPost=/bin/chgrp fail2ban /run/fail2ban/fail2ban.sock
ExecStartPost=/bin/chmod g+w /run/fail2ban/fail2ban.sock
Restart Zabbix Agent
EOF

	systemctl daemon-reload
	systemctl restart zabbix-agent fail2ban
	

	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo ; echo ;echo -e "${WHI}----------------------------------------------------------------------------------------------------${ENDCOLOR}"; echo ; echo ; echo ; echo 
}


















#
# SAINDO
#
out_here () {
    clear
    echo ;echo 
    echo -n " >> Apgando arquivos temporarios............................................"
	rm -rf $DIR
    sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo
    echo ;echo -e "${WHI}----------------------------------------------------------------------------------------------------${ENDCOLOR}"; echo ; echo ; echo ; echo 
	exit
}





#
# TESTANDO INTERNET
#
clear
net(){
	echo ;echo 
	echo -n " >> Verificando acesso a internet..........................................."
	ping -w1 www.google.com.br >/dev/null 2>&1
	while [ $? != 0 ]; do
		echo; echo -e "Sem acesso à internet! ${RED}[ERRO]${ENDCOLOR}"
		exit 1
	done
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo
}
#net

#
# VERIFICANDO SE O USUARIO EH ROOT
#
root (){
	echo -n " >> Verificando Usuario [ROOT].............................................."
	if [ $USER != root ]
	  then
	  echo "Você precisa estar logado como root! ${RED}[ERRO]${ENDCOLOR}"
	  exit 1
	fi
	sleep 0.5; echo -e "${YEL} [ OK ] ${ENDCOLOR}"; echo; echo 
	echo 
}
#root



#
# AQUI COMECA O MENU
# TENDO INTERNET ABRE O MENU
#
# --------------------------------------------------------------------------------------------
# Não alterar as linhas a baixo
# --------------------------------------------------------------------------------------------
#
echo ; echo ; echo ;echo '
#
# OBS:
# Script deve ser executado apenas Linux Debian 11 ou posterior!
# Metodo de banimento com Fail2Ban: route (blackhole)
# Script by Samir Hanna Verza
# Versão ${versao}
#
'


numchoice=1
while [ $numchoice != 0 ]; do
    echo -e "\033[94m
#
# MENU
#
.................................................\033[39m\n"
    echo -n "
1. CONFIG SERVER
2. Update e upgrade do sistem
3. Instalando aplicativos basicos
4. Configurando o banner de inicializacao
5. Versao da Blue3 do .bashrc
6. Configurando SSH
Z. Instalando Zabbix Agent
0. SAIR

Selecione a opcao a ser instalada: "
read numchoice
	case $numchoice in
		"1" ) config_server ;;
		"4" ) banner_blue3 ;;
		"5" ) install_bashrc ;;
		"6" ) config_ssh ;;
		"3" ) install_appbasic ;;
		"2" ) install_update_upgrade ;;
		"Z" | "z" ) install_zabbix ;;
		"0" | "x" | "X" | "q" | "Q" | "exit" | "EXIT" | "Exit" | "quit" | "QUIT" | "Quit"  ) out_here ;;
		* ) out_here ;;
	esac
done
exit
