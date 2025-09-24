#!/usr/bin/env bash
set -euo pipefail

# Configurações do benchmark
GRAPH_NAME="web-Google"
GRAPH_URL="https://snap.stanford.edu/data/web-Google.txt.gz"
KERNEL="pr"            # pr ou pr_spmv
THREADS_SET=(1 4 12 22 28 36 44 66 88)  # conjunto de threads
MAX_ITERS=50           # iterações do PageRank (-i)
TOLERANCE="1e-4"       # tolerância do PageRank (-t)
# export GOMP_CPU_AFFINITY="0-21 44-65"  # opcional: fixar no socket 0

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need_cmd wget
need_cmd awk
if ! command -v gunzip >/dev/null 2>&1; then need_cmd gzip; fi
need_cmd make

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gapbs_dir="$script_dir/gapbs"
data_dir="$script_dir/data"
logs_root="$script_dir/logs/$GRAPH_NAME/$KERNEL"
mkdir -p "$data_dir" "$logs_root"

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

# Descompacta (se necessário)
if [[ -s "$gz_path" && ! -s "$txt_path" ]]; then
  echo "[INFO] Descompactando -> $txt_path"
  if command -v gunzip >/dev/null 2>&1; then
    gunzip -c "$gz_path" > "$txt_path"
  else
    gzip -dc "$gz_path" > "$txt_path"
  fi
fi

# Gera .el (removendo comentários, mantendo 'src dst')
if [[ ! -s "$el_path" ]]; then
  echo "[INFO] Gerando edge list -> $el_path"
  awk '!/^#/ && NF>=2 {print $1, $2}' "$txt_path" > "$el_path"
fi

# Converte pra .sg
if [[ ! -s "$sg_path" ]]; then
  echo "[INFO] Convertendo para .sg -> $sg_path"
  "$gapbs_dir/converter" -f "$el_path" -b "$sg_path"
fi

# Loop de execuções por quantidade de threads
for T in "${THREADS_SET[@]}"; do
  export OMP_NUM_THREADS="$T"
  run_dir="$logs_root/threads-$T"
  mkdir -p "$run_dir"

  cmd=( "$gapbs_dir/$KERNEL" -f "$sg_path" -i "$MAX_ITERS" -t "$TOLERANCE" )
  ts="$(date +%Y%m%d-%H%M%S)"
  log="$run_dir/${KERNEL}_${GRAPH_NAME}_t${T}_${ts}.log"

  echo "[INFO] Rodando: ${cmd[*]}"
  echo "[INFO] OMP_NUM_THREADS=$OMP_NUM_THREADS"
  "${cmd[@]}" 2>&1 | tee "$log"

  echo "[INFO] Log salvo em: $log"
done