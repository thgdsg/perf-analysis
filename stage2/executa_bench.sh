#!/usr/bin/env bash
set -euo pipefail

# Configuração fixa do benchmark
GRAPH_NAME="web-Google"
GRAPH_URL="https://snap.stanford.edu/data/web-Google.txt.gz"
KERNEL="pr"           # pr ou pr_spmv
THREADS=24             # número fixo de threads OpenMP
MAX_ITERS=50         # iterações do PageRank (-i)
TOLERANCE="1e-4"      # tolerância do PageRank (-t)

#export GOMP_CPU_AFFINITY="0-21 44-65"
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need_cmd wget
need_cmd awk
if ! command -v gunzip >/dev/null 2>&1; then need_cmd gzip; fi
need_cmd make

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gapbs_dir="$script_dir/gapbs"
data_dir="$script_dir/data"
logs_dir="$script_dir/logs"
mkdir -p "$data_dir" "$logs_dir"

echo "[INFO] Build GAPBS (converter e $KERNEL)"
make -C "$gapbs_dir" converter "$KERNEL"

# Caminhos de dados
gz_path="$data_dir/${GRAPH_NAME}.txt.gz"
txt_path="$data_dir/${GRAPH_NAME}.txt"
el_path="$data_dir/${GRAPH_NAME}.el"
sg_path="$data_dir/${GRAPH_NAME}.sg"

# Download (se necessário)
if [[ ! -s "$gz_path" && ! -s "$txt_path" ]]; then
  echo "[INFO] Baixando $GRAPH_NAME"
  wget -O "$gz_path" "$GRAPH_URL"
fi

# Descompactar (se necessário)
if [[ -s "$gz_path" && ! -s "$txt_path" ]]; then
  echo "[INFO] Descompactando -> $txt_path"
  if command -v gunzip >/dev/null 2>&1; then
    gunzip -c "$gz_path" > "$txt_path"
  else
    gzip -dc "$gz_path" > "$txt_path"
  fi
fi

# Gerar .el (remove comentários, mantém 'src dst')
if [[ ! -s "$el_path" ]]; then
  echo "[INFO] Gerando edge list -> $el_path"
  awk '!/^#/ && NF>=2 {print $1, $2}' "$txt_path" > "$el_path"
fi

# Converter para .sg
if [[ ! -s "$sg_path" ]]; then
  echo "[INFO] Convertendo para .sg -> $sg_path"
  "$gapbs_dir/converter" -f "$el_path" -b "$sg_path"
fi

# Executar PageRank
export OMP_NUM_THREADS="$THREADS"
cmd=( "$gapbs_dir/$KERNEL" -f "$sg_path" -i "$MAX_ITERS" -t "$TOLERANCE" )

ts="$(date +%Y%m%d-%H%M%S)"
log="$logs_dir/${KERNEL}_${GRAPH_NAME}_${ts}.log"

echo "[INFO] Rodando: ${cmd[*]}"
echo "[INFO] OMP_NUM_THREADS=$OMP_NUM_THREADS"
"${cmd[@]}" 2>&1 | tee "$log"

echo "[INFO] Log salvo em: $log"