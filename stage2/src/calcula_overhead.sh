#!/usr/bin/env bash
set -euo pipefail

export GOMP_CPU_AFFINITY="0-21 44-65"
THREADS_SET=(1 4 12 22 28 36 44 66 88)
CMD_BASE="./pr -g 15 -i 50 -t 1e-4"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need_cmd vtune
need_cmd grep
need_cmd sed
need_cmd awk
need_cmd tee
need_cmd date
need_cmd make
need_cmd sort

export GOMP_CPU_AFFINITY="0-21 44-65"
source /home/intel/oneapi/vtune/2021.1.1/vtune-vars.sh
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gapbs_dir="$script_dir/gapbs"
cd "$gapbs_dir"

# compila pr se não existir
if [[ ! -x ./pr ]]; then
  echo "[INFO] Compilando pr"
  make pr
fi

out_root="$script_dir/logs/vtune_overhead"
mkdir -p "$out_root"
results_csv="$out_root/overhead_results.csv"
echo "threads,mode,baseline_s,vtune_elapsed_s,overhead_s,overhead_pct,timestamp" > "$results_csv"

parse_time_real() {
  # Extrai "real XmYs" do stderr do 'time'
  local f="$1"
  local line
  line="$(grep -E '^real' "$f" || true)"
  if [[ -n "${line:-}" ]] && [[ "$line" =~ real[[:space:]]*([0-9]+)m([0-9.]+)s ]]; then
    awk -v m="${BASH_REMATCH[1]}" -v s="${BASH_REMATCH[2]}" 'BEGIN{printf "%.6f", m*60+s}'
    return
  fi
  local num
  num="$(grep -oE '[0-9]+(\.[0-9]+)?s' "$f" | tail -1 | sed 's/s$//')"
  printf "%.6f" "${num:-0}"
}

parse_vtune_elapsed() {
  # Pega "Elapsed Time: N.NN" do log do vtune
  local f="$1"
  local num
  num="$(grep -i 'Elapsed Time:' "$f" | tail -1 | sed -n 's/.*Elapsed Time:[[:space:]]*\([0-9.]\+\).*/\1/p')"
  printf "%.6f" "${num:-0}"
}

run_vtune_mode() {
  local threads="$1" short="$2" collect="$3" base_s="$4" ts="$5" out_dir="$6"
  local vt_dir="$out_dir/vtune_${short}"
  local vt_log="$out_dir/vtune_${short}.log"
  echo "[INFO] VTune ($collect, T=$threads): vtune -collect $collect -result-dir $vt_dir -- $CMD_BASE"
  vtune -collect "$collect" -result-dir "$vt_dir" -- $CMD_BASE 2>&1 | tee "$vt_log"
  local vt_s
  vt_s="$(parse_vtune_elapsed "$vt_log")"
  local overhead_s overhead_pct
  overhead_s="$(awk -v vt="$vt_s" -v b="$base_s" 'BEGIN{printf "%.6f", vt-b}')"
  overhead_pct="$(awk -v o="$overhead_s" -v b="$base_s" 'BEGIN{ if (b>0) printf "%.2f", (o/b)*100; else print "0.00" }')"
  echo "[RESULT] T=$threads $short: baseline=${base_s}s, vtune=${vt_s}s, overhead=${overhead_s}s (${overhead_pct}%)"
  echo "$threads,$short,$base_s,$vt_s,$overhead_s,$overhead_pct,$ts" >> "$results_csv"
}

for T in "${THREADS_SET[@]}"; do
  export OMP_NUM_THREADS="$T"
  ts="$(date +%Y%m%d-%H%M%S)"
  run_root="$out_root/T${T}_$ts"
  mkdir -p "$run_root"

  # baseline com 'time' (captura stderr do time)
  time_log="$run_root/time_baseline.log"
  echo "[INFO] Baseline (time, T=$T): $CMD_BASE"
  ( time $CMD_BASE ) 1>/dev/null 2>"$time_log"
  base_s="$(parse_time_real "$time_log")"

  # três modos do VTune
  run_vtune_mode "$T" hs  hotspots              "$base_s" "$ts" "$run_root"
  run_vtune_mode "$T" ps  performance-snapshot  "$base_s" "$ts" "$run_root"
  run_vtune_mode "$T" hpc hpc-performance       "$base_s" "$ts" "$run_root"
done

# Ordena o CSV por 'mode' (coluna 2) e, em seguida, por 'threads' (coluna 1, numérico)
echo "[INFO] Ordenando CSV por 'mode' e depois por 'threads'"
tmp_csv="$(mktemp)"
{
  head -n1 "$results_csv"
  tail -n +2 "$results_csv" | sort -t, -k2,2 -k1,1n
} > "$tmp_csv"
mv "$tmp_csv" "$results_csv"

echo "[INFO] CSV final: $results_csv"