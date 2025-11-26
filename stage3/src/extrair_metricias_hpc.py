from pathlib import Path
from typing import List, Optional, Tuple

import pandas as pd

# Diretório base no Colab
BASE_DIR = Path("/content/perf-analysis/stage3")
RESULTS_ROOT = BASE_DIR / "results"
OUTPUT_CSV = BASE_DIR / "hpc_hw_metrics.csv"

def extrair_infos_caminho(rel_path_parts: List[str]) -> Optional[Tuple[str, int, bool, str, int]]:
    """
    Recebe as partes do caminho relativo a 'results' e extrai:
      GRAPH_NAME, THREADS, DISABLE_HYPERTHREADING, THREAD_BIND_POLICY, RUN.

    Espera algo do tipo:
      [GRAPH_NAME, ANALYSIS_TYPE, 'threads-X',
       'ht-true|ht-false', 'bind-<policy>', 'run-N']

    ANALYSIS_TYPE é usado apenas para filtrar 'hpc-performance'.
    
    Nota: ht-true significa que o HT foi DESATIVADO (disable_ht=True)
          ht-false significa que o HT está ATIVADO (disable_ht=False)
    """
    if len(rel_path_parts) < 6:
        return None

    graph_name = rel_path_parts[0]
    analysis_type = rel_path_parts[1]

    if analysis_type != "hpc-performance":
        return None

    threads_dir = rel_path_parts[2]
    ht_dir = rel_path_parts[3]
    bind_dir = rel_path_parts[4]
    run_dir = rel_path_parts[5]

    # threads-X
    try:
        _, threads_str = threads_dir.split("-", 1)
        threads = int(threads_str)
    except Exception:
        return None

    # ht-true|ht-false (ou disable-ht-true|disable-ht-false para compatibilidade)
    try:
        if ht_dir.startswith("ht-"):
            # Formato: "ht-true" ou "ht-false"
            ht_value = ht_dir.split("-")[1]
            # ht-true significa que o HT foi DESATIVADO, então disable_ht = True
            # ht-false significa que o HT está ATIVADO, então disable_ht = False
            disable_ht = ht_value == "true"
        elif ht_dir.startswith("disable-ht-"):
            # Formato antigo: "disable-ht-false" -> ["disable", "ht", "false"]
            # Converte string "true"/"false" para boolean
            disable_ht_str = ht_dir.split("-")[2]
            disable_ht = disable_ht_str == "true"
        else:
            return None
    except Exception:
        return None

    # bind-<policy>
    try:
        _, thread_bind_policy = bind_dir.split("-", 1)
    except Exception:
        return None

    # run-N
    try:
        _, run_str = run_dir.split("-", 1)
        run_id = int(run_str)
    except Exception:
        return None

    return graph_name, threads, disable_ht, thread_bind_policy, run_id


def extrair_metricas_hpc(report_path: str) -> Optional[Tuple[float, float, float, float]]:
    """
    Lê um report.csv de hpc-performance e retorna:
      (Average CPU Frequency, Memory Bound, Cache Bound, DRAM Bound)
    ou None se não conseguir extrair.
    """
    try:
        df = pd.read_csv(
            report_path,
            sep="\t",
            engine="python",
            header=0,
            on_bad_lines="skip",
        )
    except Exception as e:
        print(f"[AVISO] Falha ao ler {report_path}: {e}")
        return None

    def get_metric(nome: str) -> Optional[float]:
        if "Metric Name" not in df.columns or "Metric Value" not in df.columns:
            return None
        serie = df.loc[df["Metric Name"] == nome, "Metric Value"]
        if serie.empty:
            return None
        try:
            return float(serie.values[0])
        except (TypeError, ValueError):
            return None

    avg_cpu_freq = get_metric("Average CPU Frequency")
    mem_bound = get_metric("Memory Bound")
    cache_bound = get_metric("Cache Bound")
    dram_bound = get_metric("DRAM Bound")

    if any(v is None for v in (avg_cpu_freq, mem_bound, cache_bound, dram_bound)):
        # Se alguma métrica não foi encontrada, ignora este report
        return None

    return avg_cpu_freq, mem_bound, cache_bound, dram_bound


# ===== Execução principal no Colab =====

if not RESULTS_ROOT.is_dir():
    raise FileNotFoundError(f"Pasta de resultados não encontrada: {RESULTS_ROOT}")

# Coletar métricas por run
linhas: List[List[object]] = []

for report_path in RESULTS_ROOT.rglob("report.csv"):
    rel_dir = report_path.parent.relative_to(RESULTS_ROOT)
    parts = list(rel_dir.parts)

    info = extrair_infos_caminho(parts)
    if info is None:
        continue

    graph_name, threads, disable_ht, thread_bind_policy, run_id = info

    metricas = extrair_metricas_hpc(str(report_path))
    if metricas is None:
        continue

    avg_cpu_freq, mem_bound, cache_bound, dram_bound = metricas

    linhas.append(
        [
            graph_name,
            threads,
            disable_ht,
            thread_bind_policy,
            run_id,
            avg_cpu_freq,
            mem_bound,
            cache_bound,
            dram_bound,
        ]
    )

if not linhas:
    print("[INFO] Nenhuma execução hpc-performance encontrada.")
else:
    # Converte para DataFrame e agrega por configuração (média das runs)
    header = [
        "GRAPH_NAME",
        "THREADS",
        "DISABLE_HYPERTHREADING",
        "THREAD_BIND_POLICY",
        "RUN",
        "AVERAGE_CPU_FREQUENCY",
        "MEMORY_BOUND",
        "CACHE_BOUND",
        "DRAM_BOUND",
    ]
    df = pd.DataFrame(linhas, columns=header)

    group_cols = [
        "GRAPH_NAME",
        "THREADS",
        "DISABLE_HYPERTHREADING",
        "THREAD_BIND_POLICY",
    ]
    metric_cols = [
        "AVERAGE_CPU_FREQUENCY",
        "MEMORY_BOUND",
        "CACHE_BOUND",
        "DRAM_BOUND",
    ]

    df_group = df.groupby(group_cols, as_index=False)[metric_cols].mean()
    df_group = df_group.sort_values(
        by=["GRAPH_NAME", "THREADS", "DISABLE_HYPERTHREADING", "THREAD_BIND_POLICY"]
    )

    df_group.to_csv(str(OUTPUT_CSV), sep=",", index=False)
    print(f"Total de configurações hpc-performance agregadas: {len(df_group)}")
    print(f"CSV gerado em: {OUTPUT_CSV}")
    print(f"\nAmostra dos dados:")

    # Usa display() no Colab para melhor visualização
    try:
        from IPython.display import display
        display(df_group.head())
    except ImportError:
        # Se não estiver no Colab, usa print normal
        print(df_group.head())

