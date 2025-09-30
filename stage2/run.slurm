#!/bin/bash
#
# SLURM job para executar o pipeline atual do projeto perf-analysis (stage2),
# cujo entrypoint é o script perf_analysis_pr.sh. Esse script já cuida de:
# - preparar/compilar GAPBS (quando necessário)
# - carregar o ambiente do VTune
# - gerar comandos e executar os experimentos
# Portanto este job apenas prepara o ambiente de execução e chama o script.

#SBATCH --job-name=vtune-gapbs
#SBATCH --partition=blaise
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

set -euo pipefail

# Diretório base do projeto (ajuste se enviar de outro local com --chdir)
PROJECT_DIR="$(dirname "$0")"
cd "$PROJECT_DIR"

echo "[INFO] Iniciando job em: $(pwd)"
echo "[INFO] Hostname: $(hostname)"
echo "[INFO] Data/Hora: $(date)"
echo "[INFO] SLURM_JOB_ID: ${SLURM_JOB_ID:-n/a}"

# Opcional: carregar módulos se o cluster usar environment-modules (comente se não for o caso)
# module load intel-oneapi-vtune

# Garantir permissões de execução
chmod +x ./perf_analysis_pr.sh || true

# Delegar toda a orquestração ao script principal do projeto
./perf_analysis_pr.sh

echo "[INFO] Job finalizado com sucesso."
