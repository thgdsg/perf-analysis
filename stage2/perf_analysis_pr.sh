#!/bin/bash

# Verifica se a pasta gapbs existe no diretório src
# Se não existe, clona o repositório e compila
if [ ! -d "src/gapbs" ]; then
    echo "Pasta gapbs não encontrada em src/. Clonando repositório..."
    cd src
    git clone https://github.com/sbeamer/gapbs.git
    echo "Repositório gapbs clonado com sucesso!"
    
    echo "Compilando GAPBS..."
    cd gapbs
    make
    if [ $? -eq 0 ]; then
        echo "GAPBS compilado com sucesso!"
    else
        echo "Erro ao compilar GAPBS!"
        exit 1
    fi
    cd ../..
else
    echo "Pasta gapbs já existe em src/."
fi

# Vtune
source /home/intel/oneapi/vtune/2021.1.1/vtune-vars.sh

# Define o governor de performance para utilizar o máximo de frequência
cpufreq-set -g performance

# Gera os comandos
python3 ./src/build_commad.py

# Executa todos os comandos
./src/commands.sh