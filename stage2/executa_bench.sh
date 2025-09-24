#!/usr/bin/env bash
set -euo pipefail

# Dependências básicas
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need_cmd wget
need_cmd awk
if ! command -v gunzip >/dev/null 2>&1; then need_cmd gzip; fi
need_cmd make
need_cmd tee
need_cmd tr
need_cmd date

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gapbs_dir="$script_dir/gapbs"
data_dir="$script_dir/data"
logs_root="$script_dir/logs"
experiments_csv="$script_dir/experiments.csv"

[[ -f "$experiments_csv" ]] || { echo "[ERRO] Não encontrado: $experiments_csv"; exit 1; }

mkdir -p "$data_dir" "$logs_root"

# 1) Descobre todos os kernels necessários no CSV e compila de uma vez
declare -A kernels_set=()
while IFS=, read -r CSV_GRAPH_NAME CSV_GRAPH_URL CSV_KERNEL CSV_THREADS CSV_MAX_ITERS CSV_TOL || [[ -n "${CSV_GRAPH_NAME:-}" ]]; do
  # pular cabeçalho/linhas vazias
  [[ -z "${CSV_GRAPH_NAME:-}" ]] && continue
  [[ "$CSV_GRAPH_NAME" == "GRAPH_NAME" ]] && continue
  kernels_set["$CSV_KERNEL"]=1
done < <(tr -d '\r' < "$experiments_csv")

kernels_to_build=()
for k in "${!kernels_set[@]}"; do
  [[ -n "$k" ]] && kernels_to_build+=("$k")
done

echo "[INFO] Compilando GAPBS: converter ${kernels_to_build[*]}"
make -C "$gapbs_dir" converter "${kernels_to_build[@]}"

# 2) Itera cada linha do CSV e executa
while IFS=, read -r GRAPH_NAME GRAPH_URL KERNEL THREADS MAX_ITERS TOLERANCE || [[ -n "${GRAPH_NAME:-}" ]]; do
  # pular cabeçalho/linhas vazias
  [[ -z "${GRAPH_NAME:-}" ]] && continue
  [[ "$GRAPH_NAME" == "GRAPH_NAME" ]] && continue

  # Pastas por grafo/kernel
  graph_dir="$data_dir/$GRAPH_NAME"
  logs_dir="$logs_root/$GRAPH_NAME/$KERNEL/threads-$THREADS"
  mkdir -p "$graph_dir" "$logs_dir"

  # Baixar arquivo original (usa o nome do recurso da URL)
  download_path="$graph_dir/$(basename "$GRAPH_URL")"
  if [[ ! -s "$download_path" ]]; then
    echo "[INFO] Baixando ($GRAPH_NAME): $GRAPH_URL"
    wget -O "$download_path" "$GRAPH_URL"
  fi

  # Determina arquivo texto (descompacta se for .gz)
  text_path="$download_path"
  if [[ "$download_path" == *.gz ]]; then
    text_path="${download_path%.gz}"
    if [[ ! -s "$text_path" ]]; then
      echo "[INFO] Descompactando -> $text_path"
      if command -v gunzip >/dev/null 2>&1; then
        gunzip -c "$download_path" > "$text_path"
      else
        gzip -dc "$download_path" > "$text_path"
      fi
    fi
  fi

  # Gera edge list .el (remove comentários, mantém "src dst")
  el_path="$graph_dir/${GRAPH_NAME}.el"
  if [[ ! -s "$el_path" ]]; then
    echo "[INFO] Gerando edge list -> $el_path"
    awk '!/^#/ && NF>=2 {print $1, $2}' "$text_path" > "$el_path"
  fi

  # Converte para .sg
  sg_path="$graph_dir/${GRAPH_NAME}.sg"
  if [[ ! -s "$sg_path" ]]; then
    echo "[INFO] Convertendo para .sg -> $sg_path"
    "$gapbs_dir/converter" -f "$el_path" -b "$sg_path"
  fi

  # Executa kernel
  export OMP_NUM_THREADS="$THREADS"
  cmd=( "$gapbs_dir/$KERNEL" -f "$sg_path" -i "$MAX_ITERS" -t "$TOLERANCE" )
  ts="$(date +%Y%m%d-%H%M%S)"
  log="$logs_dir/${KERNEL}_${GRAPH_NAME}_t${THREADS}_${ts}.log"

  echo "[INFO] Rodando: ${cmd[*]}"
  echo "[INFO] OMP_NUM_THREADS=$OMP_NUM_THREADS"
  "${cmd[@]}" 2>&1 | tee "$log"
  echo "[INFO] Log salvo em: $log"
done < <(tr -d '\r' < "$experiments_csv")