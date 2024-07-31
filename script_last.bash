#!/bin/bash

#
#
#
#  * Autor: Samir Hanna Verza
#  * Criado: 20/01/2023
#  *
#  * Ult. Atualizacao:
#  * Data: 17/05/2024
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
Ipv4=$(ip addr show | grep inet | awk '{print $2}' | sed -n -e 3,3p)
Ipv6=$(ip addr show | grep inet | awk '{print $2}' | sed -n -e 4,4p)
IP=$(ip addr show | grep inet | awk '{print $2}' | sed -n -e 3,3p | cut -d "/" -f 1)
if ! command -v lsb_release &>/dev/null; then
	apt install -y lsb-release
fi
distroName=$(lsb_release -i | awk '{print $3}')
distroCodeName=$(lsb_release -c | awk '{print $2}')
kernelRelease=$(uname -r)
DIR=$(pwd)
User=$(whoami)


