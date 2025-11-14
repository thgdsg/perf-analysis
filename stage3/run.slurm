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
#SBATCH --time=24:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

set -euo pipefail

# Verifica se a variável SCRATCH está definida
if [[ -z "${SCRATCH:-}" ]]; then
  echo "[ERRO] A variável de ambiente SCRATCH não está definida. Abortando." >&2
  exit 1
fi

# Diretório de destino para os resultados no HOME
HOME_RESULTS_DIR="${HOME}/perf-analysis/stage3"

# Diretório do repositório no SCRATCH
REPO_DIR_IN_SCRATCH="${SCRATCH}/perf-analysis"

# Remove o diretório do repositório se ele já existir para garantir uma cópia limpa
if [[ -d "$REPO_DIR_IN_SCRATCH" ]]; then
  echo "[INFO] Removendo diretório existente: $REPO_DIR_IN_SCRATCH"
  rm -rf "$REPO_DIR_IN_SCRATCH"
fi

# Navega para o diretório SCRATCH e clona o repositório
echo "[INFO] Navegando para $SCRATCH e clonando o repositório..."
cd "$SCRATCH"
git clone https://github.com/thgdsg/perf-analysis.git

# Define o diretório de trabalho do projeto e entra nele
PROJECT_DIR="${REPO_DIR_IN_SCRATCH}/stage3"
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

# Cria o diretório de resultados no HOME se não existir e copia os resultados
echo "[INFO] Copiando resultados de $PROJECT_DIR/results para $HOME_RESULTS_DIR"
mkdir -p "$HOME_RESULTS_DIR"
cp -r "$PROJECT_DIR"/results "$HOME_RESULTS_DIR"/
cp -r "$PROJECT_DIR"/logs "$HOME_RESULTS_DIR"/

python3 ./src/unify_all_results.py
echo "[INFO] Job finalizado com sucesso."