# Blue3 Start Script

Script inicial para provisionamento manual de servidores Debian.

O objetivo deste projeto e padronizar as primeiras configuracoes de um servidor Linux Debian com menu interativo, mantendo log, backup e pontos de ajuste rapido no inicio do script.

## Arquivos

- `start.sh`: script principal de configuracao inicial
- `README.md`: documentacao de uso e manutencao
- `VERSION`: versao local do projeto
- `.env.example`: modelo de configuracao local para gerar `.env_start`
- `templates/`: blocos externos usados pelo script

## O que o script faz

O menu atual oferece estas etapas:

1. Configurar hostname, `/etc/hosts` e arquivo de rede
2. Executar `apt update`, `upgrade`, `clean` e `autoremove`
3. Instalar aplicativos basicos de administracao
4. Aplicar perfil de VM Proxmox
5. Aplicar banner BLUE3 no login
6. Aplicar `.bashrc` BLUE3 para o usuario root
7. Configurar SSH via `sshd_config.d`
8. Instalar e configurar sincronismo NTP
9. Atualizar mirror APT
A. Agendar regeneracao das host keys SSH no proximo boot
U. Verificar e aplicar autoatualizacao do projeto via GitHub
Z. Instalar e configurar Zabbix Agent

## Melhorias aplicadas nesta versao

O script foi reorganizado para corrigir problemas do modelo anterior:

- usa `set -Eeuo pipefail`
- valida root antes de iniciar
- valida se o sistema e Debian suportado
- registra execucao em log real com timestamp unico
- cria backups antes de alterar arquivos criticos
- usa `sshd -t` antes de reiniciar o SSH
- remove diretivas obsoletas do OpenSSH
- evita `sed` agressivo no arquivo principal do SSH
- reescreve configuracoes criticas com heredoc legivel
- deixa variaveis sensiveis concentradas no topo do script
- move blocos grandes para templates externos
- suporta arquivo `.env_start` local para customizacao do ambiente
- usa arquivo `VERSION` para controle de versao local
- prepara autoatualizacao do projeto via GitHub por tarball do repositorio

## Controle de versao do projeto

O projeto agora possui um arquivo dedicado:

```text
VERSION
```

Esse arquivo e a fonte da versao local do projeto. O `start.sh` le esse valor na inicializacao e compara com a versao publicada no GitHub quando a rotina de autoatualizacao e executada.

Esse modelo e melhor do que deixar a versao apenas dentro do script porque:

- facilita a manutencao
- permite comparacao remota simples
- evita ter que parsear o corpo inteiro do shell script

## Autoatualizacao via GitHub

O script agora suporta autoatualizacao do projeto usando o repositorio GitHub configurado no `.env_start`.

Variaveis novas:

```bash
UPDATE_REPO_OWNER=samirhvbr
UPDATE_REPO_NAME=Linux-Start
UPDATE_REPO_BRANCH=master
```

Fluxo da atualizacao:

1. consulta `VERSION` remoto em `raw.githubusercontent.com`
2. compara com a versao local usando ordenacao de versao
3. baixa o tarball do branch configurado se houver versao mais nova
4. extrai o projeto para uma pasta temporaria
5. faz backup do projeto atual
6. sobrescreve os arquivos do projeto local
7. reinicia o script atualizado

Backups da autoatualizacao ficam dentro do diretório de backup da execucao atual.

## Situacao atual do repositorio remoto

Foi verificado o repositorio:

- `https://github.com/samirhvbr/Linux-Start`

No momento da checagem, o branch `master` ainda estava com a versao antiga do `start.sh` e sem `VERSION` publicado. Entao:

- o mecanismo novo ja esta pronto localmente
- ele passa a funcionar de verdade assim que esta nova estrutura for enviada ao GitHub

Em outras palavras: a melhor pratica foi implementada no projeto local, mas o repositorio remoto ainda precisa receber esses arquivos novos para a autoatualizacao encontrar uma versao remota valida.

## Estrutura de templates

Os blocos maiores de manutencao foram separados em arquivos dentro de `templates/`:

- `templates/banner/10-uname.tpl`
- `templates/banner/20-blue3.tpl`
- `templates/bash/root.bashrc.tpl`
- `templates/ssh/blue3-hardening.conf.tpl`
- `templates/ssh/blue3-root-ipath.conf.tpl`
- `templates/ssh/rhosts.conf.tpl`

Com isso, alteracoes de banner, bashrc e SSH nao precisam mais ser feitas diretamente no corpo do `start.sh`.

## Uso de .env_start

Sim, usar um arquivo de ambiente aqui faz sentido como boa pratica, desde que ele seja tratado como configuracao local e nao como arquivo versionado com dados sensiveis.

O script procura automaticamente por:

```bash
.env_start
```

no mesmo diretorio do projeto. Se o arquivo nao existir, ele usa os valores padrao embutidos no script.

O fluxo recomendado e:

```bash
cp .env.example .env_start
```

Depois disso, ajuste os valores do seu ambiente local.

## Variaveis de ajuste rapido

Estas variaveis podem ficar no `.env_start` para facilitar a adaptacao para outros ambientes:

```bash
REQUIRED_DEBIAN_MAJOR="${REQUIRED_DEBIAN_MAJOR:-11}"
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-b3.local}"
DEFAULT_SSH_PORT="${DEFAULT_SSH_PORT:-22}"
DEFAULT_LOGIN_GRACE="${DEFAULT_LOGIN_GRACE:-30}"
DEFAULT_ROOT_IPS="${DEFAULT_ROOT_IPS:-100.64.66.0/24,170.233.230.254,170.233.230.222}"
DEFAULT_ZABBIX_SERVER="${DEFAULT_ZABBIX_SERVER:-100.64.66.8}"
UPDATE_REPO_OWNER="${UPDATE_REPO_OWNER:-samirhvbr}"
UPDATE_REPO_NAME="${UPDATE_REPO_NAME:-Linux-Start}"
UPDATE_REPO_BRANCH="${UPDATE_REPO_BRANCH:-master}"
ZABBIX_RELEASE_URL="${ZABBIX_RELEASE_URL:-}"
```

Essas configuracoes sao carregadas antes das validacoes principais do script.

## Logs e backups

Cada execucao cria:

- log em `/root/blue3_start_YYYYMMDDHHMMSS.log`
- backup em `/root/blue3_start_YYYYMMDDHHMMSS/`

Arquivos alterados, como SSH, rede, hosts, MOTD e `.bashrc`, passam a ter backup antes de qualquer sobrescrita.

## Requisitos

O script foi preparado para:

- Debian 11 ou superior
- execucao como `root`
- acesso a internet para etapas de pacote e Zabbix

Comandos esperados no host:

```bash
apt awk cp cut date getent grep hostname hostnamectl ip mkdir mv ping sed sshd systemctl tee wget
```

## Como usar

Para baixar o projeto direto no servidor via Git:

```bash
apt update && apt install -y git
git clone -b master https://github.com/samirhvbr/Linux-Start.git
cd Linux-Start
```

Depois, execute como root:

```bash
bash start.sh
```

Tambem e possivel sobrescrever variaveis no momento da chamada:

```bash
DEFAULT_SSH_PORT=2222 DEFAULT_DOMAIN=empresa.local bash start.sh
```

Se preferir um arquivo dedicado em outro caminho, tambem e possivel usar:

```bash
BLUE3_ENV_FILE=/caminho/arquivo.env_start bash start.sh
```

## Comportamento das funcoes principais

### Config server

- detecta hostname, dominio, interface padrao e IP atual
- permite atualizar hostname
- pode reescrever `/etc/hosts`
- pode reescrever `/etc/network/interfaces`
- nao reinicia automaticamente a rede; deixa a revisao final para o operador

### SSH

- cria arquivos em `/etc/ssh/sshd_config.d/`
- usa templates do diretorio `templates/ssh/`
- define `PermitRootLogin no` globalmente
- libera root apenas para IPs definidos em `Match Address`
- valida a configuracao com `sshd -t`
- so reinicia o servico se a validacao passar

### Perfil Proxmox VM

- atualiza os indices do APT antes da instalacao
- instala `qemu-guest-agent`, `rsync`, `nano`, `htop`, `curl`, `wget` e `net-tools`
- habilita `qemu-guest-agent` imediatamente
- oferece instalacao opcional de `cloud-init` e `cloud-initramfs-growroot`
- habilita `fstrim.timer` quando disponivel
- garante `/root/.ssh` com permissao `700`
- oferece limpeza opcional de cache, journals antigos e logs rotacionados
- oferece preparacao opcional para template/clone limpando `machine-id` e estado do `cloud-init`
- dentro da preparacao para template, oferece remocao opcional das chaves host SSH e pode agendar a regeneracao automatica no proximo boot

### Regeneracao de host keys SSH no proximo boot

- cria um servico `systemd` `oneshot` para executar apenas uma vez no proximo boot
- usa `ssh-keygen -A` para recriar apenas as host keys ausentes
- remove o proprio script e a propria unit depois da execucao
- e a opcao mais adequada quando a VM sera transformada em template ou quando o clone ainda nao iniciou com identidade definitiva

### Banner e bashrc

- o banner BLUE3 e aplicado a partir dos templates em `templates/banner/`
- o `.bashrc` do root e aplicado a partir de `templates/bash/root.bashrc.tpl`
- ajustes visuais e aliases agora ficam fora do script principal

### Zabbix

- tenta instalar `zabbix-agent` pelos repositorios atuais
- se o pacote nao existir, usa `ZABBIX_RELEASE_URL` quando definido
- cria configuracao em `zabbix_agentd.d`
- adiciona user parameters para fail2ban
- cria override do systemd para permissao do socket do fail2ban quando necessario

### Atualizacao do projeto

- consulta `VERSION` remoto no GitHub
- baixa o tarball do branch configurado
- faz backup do projeto antes da substituicao
- reinicia o script atualizado ao final

## Observacoes importantes

- o script e interativo; nao foi convertido para modo totalmente nao interativo
- o `.env_start` e recomendado para defaults locais, mas nao substitui a revisao manual de rede e SSH
- a autoatualizacao depende de o repositorio remoto conter `VERSION`, `start.sh` e a pasta `templates/`
- a etapa de rede pode derrubar acesso remoto se aplicada sem revisao
- a etapa de perfil Proxmox pode limpar `machine-id` se o operador confirmar preparacao para template
- a regeneracao agendada de host keys SSH so deve ser usada quando a identidade SSH atual puder ser descartada com seguranca
- a etapa de SSH altera politica de acesso root e porta; deve ser testada com cuidado
- o script assume uso de `ifupdown` em `/etc/network/interfaces`
- para servidores com `cloud-init`, `NetworkManager` ou `systemd-networkd`, a etapa de rede deve ser revisada antes do uso

## Proximos passos recomendados

Melhorias naturais para fases futuras:

1. criar modo nao interativo por variaveis ou arquivo `.env_start`
2. separar blocos grandes em arquivos de template
3. adicionar validacao de IP, CIDR e porta antes de escrever configuracoes
4. incluir testes de sintaxe automatizados no projeto
5. adicionar opcao para aplicar configuracoes em lote