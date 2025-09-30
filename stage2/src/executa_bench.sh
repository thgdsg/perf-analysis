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
    echo "[INFO] ENABLE_LOGS=$ENABLE_LOGS"
    echo ""
}

# Função principal para parse dos argumentos
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -threads)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -threads requer um valor"
                    exit 1
                fi
                THREADS="$2"
                shift 2
                ;;
            -max-iters)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -max-iters requer um valor"
                    exit 1
                fi
                MAX_ITERS="$2"
                shift 2
                ;;
            -tolerance)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -tolerance requer um valor"
                    exit 1
                fi
                TOLERANCE="$2"
                shift 2
                ;;
            -graph-name)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -graph-name requer um valor"
                    exit 1
                fi
                GRAPH_NAME="$2"
                shift 2
                ;;
            -graph-url)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -graph-url requer um valor"
                    exit 1
                fi
                GRAPH_URL="$2"
                shift 2
                ;;
            -kernel)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -kernel requer um valor"
                    exit 1
                fi
                KERNEL="$2"
                shift 2
                ;;
            -analysis-type)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -analysis-type requer um valor"
                    exit 1
                fi
                ANALYSIS_TYPE="$2"
                shift 2
                ;;
            -gap-logs)
                ENABLE_LOGS=true
                shift
                ;;
            -thread-bind-policy)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -thread-bind-policy requer um valor"
                    exit 1
                fi
                THREAD_BIND_POLICY="$2"
                shift 2
                ;;
            -disable-hyperthreading)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    echo "Erro: -disable-hyperthreading requer um valor"
                    exit 1
                fi
                DISABLE_HYPERTHREADING="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Parâmetro desconhecido: $1"
                echo "Use -h ou --help para ver as opções disponíveis"
                exit 1
                ;;
        esac
    done
}

get_graph_data() {
  # Pastas por grafo/kernel
  graph_dir="$data_dir/$GRAPH_NAME"
  logs_dir="$logs_root/$GRAPH_NAME/$KERNEL/threads-$THREADS"
  mkdir -p "$graph_dir"
  
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

# Valida parâmetros obrigatórios
validate_required_params

# Mostra os parâmetros parseados
show_parsed_params

# Verifica se disable_hyperthreading é "true" e imprime "oi"
if [[ "$DISABLE_HYPERTHREADING" == "true" ]]; then
  echo "oi"
else
  echo "oi2"
fi

# Cria as pastas de dados, resultados e logs (logs apenas se habilitado)
results_dir="./results/$GRAPH_NAME/$ANALYSIS_TYPE/threads-$THREADS/hyperthreading-$DISABLE_HYPERTHREADING"

mkdir -p "$data_dir"
mkdir -p "$results_dir"

if [[ "$ENABLE_LOGS" == "true" ]]; then
  mkdir -p "$logs_root"
fi

# Cria os dados do grafo
get_graph_data

# Seta as variáveis do OpenMP
export OMP_NUM_THREADS="$THREADS"
export OMP_THREAD_BIND_POLICY="$THREAD_BIND_POLICY"

cmd=( "vtune" "-collect" "$ANALYSIS_TYPE" "-result-dir" "$results_dir" "--" "$gapbs_dir/$KERNEL" "-f" "$el_path" "-i" "$MAX_ITERS" "-t" "$TOLERANCE" )

echo "[INFO] Rodando: ${cmd[*]}"
echo "[INFO] Variáveis de ambiente OpenMP:"
echo "[INFO] OMP_NUM_THREADS=$OMP_NUM_THREADS"
echo "[INFO] OMP_THREAD_BIND_POLICY=$OMP_THREAD_BIND_POLICY"

if [[ "$ENABLE_LOGS" == "true" ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  log="$logs_dir/${KERNEL}_${GRAPH_NAME}_t${THREADS}_${ts}.log"
  "${cmd[@]}" 2>&1 | tee "$log"
  echo "[INFO] Log salvo em: $log"
else
  "${cmd[@]}"
  echo "[INFO] Execução concluída (logs desabilitados)"
fi


# Gera o relatório
vtune -report summary \
  -result-dir "$results_dir" \
  -format csv \
  -report-output "$results_dir/report.csv"