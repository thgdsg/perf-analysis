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
data_dir="./data"
logs_root="./logs"

# Vars para o script (valores padrão)
THREADS=1
MAX_ITERS=50
TOLERANCE=1e-4
KERNEL=pr
ANALYSIS_TYPE=performance-snapshot
ENABLE_LOGS=false
GRAPH_NAME=""
GRAPH_URL=""
THREAD_BIND_POLICY=""
DISABLE_HYPERTHREADING=""
RUN_ID=1 # Valor padrão para o ID da execução
VTUNE_ENABLE="true" # padrão: profiler ligado

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [opções]"
    echo "Opções:"
    echo "  -threads N        Número de threads (padrão: 1)"
    echo "  -analysis-type TYPE        Tipo de análise (padrão: performance-snapshot)"
    echo "  -max-iters N      Máximo de iterações (padrão: 50)"
    echo "  -tolerance T      Tolerância (padrão: 1e-4)"
    echo "  -graph-name NAME  Nome do grafo (obrigatório)"
    echo "  -graph-url URL    URL do grafo"
    echo "  -kernel KERNEL    Kernel a executar (obrigatório)"
    echo "  -gap-logs         Habilita criação de logs"
    echo "  -thread-bind-policy POLICY  Política de bind (spread, close)"
    echo "  -disable-hyperthreading true|false  Usa somente núcleos físicos"
    echo "  -run-id ID        ID da execução (para criar pastas de resultado únicas)"
    echo "  -vtune-enable true|false  Habilita/desabilita o Intel VTune Profiler"
    echo "  -h, --help        Mostra esta ajuda"
}

# Função para validar parâmetros obrigatórios
validate_required_params() {
    local errors=0
    
    if [[ -z "$KERNEL" ]]; then
        echo "Erro: -kernel é obrigatório"
        errors=1
    fi

    if [[ -z "$GRAPH_NAME" ]]; then
        echo "Erro: -graph-name é obrigatório"
        errors=1
    fi
    
    if [[ $errors -eq 1 ]]; then
        echo ""
        show_help
        exit 1
    fi
}

# Função para mostrar parâmetros parseados
show_parsed_params() {
    echo "[INFO] Parâmetros configurados:"
    echo "[INFO] THREADS=$THREADS"
    echo "[INFO] MAX_ITERS=$MAX_ITERS"
    echo "[INFO] TOLERANCE=$TOLERANCE"
    echo "[INFO] GRAPH_NAME=${GRAPH_NAME:-'(não definido)'}"
    echo "[INFO] GRAPH_URL=${GRAPH_URL:-'(não definido)'}"
    echo "[INFO] KERNEL=$KERNEL"
    echo "[INFO] ANALYSIS_TYPE=${ANALYSIS_TYPE:-'(não definido)'}"
    echo "[INFO] THREAD_BIND_POLICY=${THREAD_BIND_POLICY:-'(não definido)'}"
    echo "[INFO] DISABLE_HYPERTHREADING=${DISABLE_HYPERTHREADING:-'(não definido)'}"
    echo "[INFO] VTUNE_ENABLE=${VTUNE_ENABLE:-'(não definido)'}"
    echo "[INFO] ENABLE_LOGS=$ENABLE_LOGS"
    echo ""
}

# Função principal para parse dos argumentos
parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -threads) THREADS="$2"; shift ;;
      -max-iters) MAX_ITERS="$2"; shift ;;
      -tolerance) TOLERANCE="$2"; shift ;;
      -graph-name) GRAPH_NAME="$2"; shift ;;
      -graph-url) GRAPH_URL="$2"; shift ;;
      -kernel) KERNEL="$2"; shift ;;
      -analysis-type) ANALYSIS_TYPE="$2"; shift ;;
      -gap-logs) ENABLE_LOGS=true ;;
      -thread-bind-policy) THREAD_BIND_POLICY="$2"; shift ;;
      -disable-hyperthreading) DISABLE_HYPERTHREADING="$2"; shift ;;
      -run-id) RUN_ID="$2"; shift ;;
      -vtune-enable) VTUNE_ENABLE="$2"; shift ;;
      -h|--help) show_help; exit 0 ;;
      *) echo "Opção desconhecida: $1"; show_help; exit 1 ;;
    esac
    shift
  done
}

get_graph_data() {
  # Pastas por grafo/kernel
  graph_dir="$data_dir/$GRAPH_NAME"
  logs_dir="$logs_root/$GRAPH_NAME/$ANALYSIS_TYPE/threads-$THREADS/ht-$DISABLE_HYPERTHREADING/bind-$THREAD_BIND_POLICY/run-$RUN_ID"
  mkdir -p "$graph_dir"

  # Remover a pasta de logs específica desta execução se ela já existir
  if [[ -d "$logs_dir" ]]; then
    echo "[INFO] Removendo pasta de logs existente: $logs_dir"
    rm -rf "$logs_dir"
  fi
  
  # Cria diretório de logs apenas se habilitado
  if [[ "$ENABLE_LOGS" == "true" ]]; then
    mkdir -p "$logs_dir"
  fi

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

}

# Executa o parse dos argumentos
parse_arguments "$@"

# Se VTune desabilitado, captura todo o output em logs (ignora -gap-logs)
if [[ "$VTUNE_ENABLE" == "false" ]]; then
  ENABLE_LOGS=true
fi

# Valida parâmetros obrigatórios
validate_required_params

# Mostra os parâmetros parseados
show_parsed_params

# Afinidade de threads conforme a flag de hyperthreading
if [[ "$DISABLE_HYPERTHREADING" == "true" ]]; then

  # OpenMP: usa apenas núcleos físicos (1 thread por core)
  export OMP_PLACES=cores

  # libgomp: fixa 1 logical por core (primeiro irmão de cada core)
  export GOMP_CPU_AFFINITY="$(
    lscpu -e=CPU,CORE,ONLINE | awk 'NR>1 && $3=="yes"{core=$2; if (!(core in first)) {first[core]=$1} if (core>max) max=core}
      END{sep=""; for(i=0;i<=max;i++){ if (i in first){ printf "%s%s", sep, first[i]; sep="," }}}'
  )"

  # Lista de CPUs para taskset (1 logical por core)
  cpu_list="$(
    lscpu -e=CPU,CORE,ONLINE | awk 'NR>1 && $3=="yes"{c=$2; if (!(c in f)) {f[c]=$1} if (c>max) max=c}
      END{for(i=0;i<=max;i++) if (i in f) {printf (n?",":""); printf "%s", f[i]; n=1}}'
  )"
else
  export OMP_PLACES=threads

  # libgomp: liste primeiro 1 logical por core, depois os hyperthreads (mantém bom escalonamento com N<44)
  export GOMP_CPU_AFFINITY="$(
    lscpu -e=CPU,CORE,ONLINE | awk 'NR>1 && $3=="yes"{core=$2; if (!(core in first)) {first[core]=$1} else {second[core]=$1} if (core>max) max=core}
      END{
        sep="";
        for(i=0;i<=max;i++){ if (i in first){ printf "%s%s", sep, first[i]; sep="," }}
        for(i=0;i<=max;i++){ if (i in second){ printf "%s%s", sep, second[i]; sep="," }}
      }'
  )"
fi

# Cria as pastas de dados, resultados e logs
# A estrutura agora inclui a política de bind e o ID da execução
results_dir="./results/$GRAPH_NAME/$ANALYSIS_TYPE/threads-$THREADS/ht-$DISABLE_HYPERTHREADING/bind-$THREAD_BIND_POLICY/run-$RUN_ID"

# Remover a pasta de resultados específica desta execução se ela já existir
if [[ -d "$results_dir" ]]; then
  echo "[INFO] Removendo pasta de resultados existente: $results_dir"
  rm -rf "$results_dir"
fi

mkdir -p "$data_dir"
mkdir -p "$results_dir"

if [[ "$ENABLE_LOGS" == "true" ]]; then
  mkdir -p "$logs_root"
fi

# Cria os dados do grafo
get_graph_data

# Seta as variáveis do OpenMP
export OMP_NUM_THREADS="$THREADS"
export OMP_PROC_BIND="$THREAD_BIND_POLICY"

# Monta o comando conforme HT e VTune
if [[ "$VTUNE_ENABLE" == "true" ]]; then
  if [[ "$DISABLE_HYPERTHREADING" == "true" ]]; then
    echo "[INFO] HT off via taskset em CPUs: $cpu_list"
    cmd=( taskset -c "$cpu_list" vtune -collect "$ANALYSIS_TYPE" -result-dir "$results_dir" -- "$gapbs_dir/$KERNEL" -f "$el_path" -i "$MAX_ITERS" -t "$TOLERANCE" )
  else
    cmd=( vtune -collect "$ANALYSIS_TYPE" -result-dir "$results_dir" -- "$gapbs_dir/$KERNEL" -f "$el_path" -i "$MAX_ITERS" -t "$TOLERANCE" )
  fi
else
  # Execução sem VTune; aplica taskset quando HT off
  if [[ "$DISABLE_HYPERTHREADING" == "true" ]]; then
    echo "EXECUTANDO SEM VTUNE"
    echo "[INFO] HT off via taskset em CPUs: $cpu_list"
    cmd=( taskset -c "$cpu_list" "$gapbs_dir/$KERNEL" -f "$el_path" -i "$MAX_ITERS" -t "$TOLERANCE" )
  else
    cmd=( "$gapbs_dir/$KERNEL" -f "$el_path" -i "$MAX_ITERS" -t "$TOLERANCE" )
  fi
fi

echo "[INFO] Rodando: ${cmd[*]}"
echo "[INFO] Variáveis de ambiente OpenMP:"
echo "[INFO] OMP_NUM_THREADS=$OMP_NUM_THREADS"
echo "[INFO] OMP_PLACES=${OMP_PLACES:-'(não definido)'}"
echo "[INFO] OMP_PROC_BIND=${OMP_PROC_BIND:-'(não definido)'}"
echo "[INFO] GOMP_CPU_AFFINITY=${GOMP_CPU_AFFINITY:-'(não definido)'}"

if [[ "$ENABLE_LOGS" == "true" ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  log="$logs_root/$GRAPH_NAME/$ANALYSIS_TYPE/threads-$THREADS/ht-$DISABLE_HYPERTHREADING/bind-$THREAD_BIND_POLICY/run-$RUN_ID/${KERNEL}_${GRAPH_NAME}_t${THREADS}_${RUN_ID}_${ts}.log"
  "${cmd[@]}" 2>&1 | tee "$log"
  echo "[INFO] Log salvo em: $log"
else
  "${cmd[@]}"
  echo "[INFO] Execução concluída (logs desabilitados)"
fi

# Report do VTune somente quando habilitado
if [[ "$VTUNE_ENABLE" == "true" ]]; then
  vtune -report summary \
    -result-dir "$results_dir" \
    -format csv \
    -report-output "$results_dir/report.csv"
fi