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

HOME_DIR="${HOME}/perf-analysis/stage2"

# Define o diretório do projeto no SCRATCH, com fallback para o diretório do script
if [[ -n "${SCRATCH:-}" ]]; then
  PROJECT_DIR="${SCRATCH}/perf-analysis/stage2"
  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "[WARN] Diretório não existe em SCRATCH: $PROJECT_DIR. Usando diretório do script."
    PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
  fi
else
  echo "[WARN] SCRATCH não definido. Usando diretório do script."
  PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
cd "$PROJECT_DIR"

# Coloca o governor DVFS em performance pra todos os cores
for i in $(seq 0 $(( $(nproc) - 1 ))); do
    cpufreq-set -c $i -g performance
done

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

cp -r "$PROJECT_DIR"/results "$HOME_DIR"/results

echo "[INFO] Job finalizado com sucesso."
