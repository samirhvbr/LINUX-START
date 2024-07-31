#!/bin/bash

#
#
#
#  * Autor: Samir Hanna Verza
#  * Criado: 16/05/2024
#  *
#  * Ult. Atualizacao:
#  * Data: 16/05/2024
#
#
#
VERSAO=100



#
# CARREGAR ARQUIVO MAIS RECENTE DO SCRIPT
#
DIR=$(pwd)
wget https://files.b3.rs/blue3/script_last.bash -O $DIR/script_last.bash
    if [ ! -s $DIR/script_last.bash ]; then
        echo "O arquivo $DIR/script_last.bash não existe ou está vazio."
        echo "ERROR: 1"
        exit 1
    fi
chmod +x $DIR/script_last.bash

# EXECUTAR O SCRIPT MAIS RECENTE
source $DIR/script_last.bash
