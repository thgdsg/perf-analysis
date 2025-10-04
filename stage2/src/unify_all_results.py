import pandas as pd
import subprocess
import time

def setSequencialTime(dic_key):
    df = pd.read_csv("unified_results.csv", sep=",")

    csv_values = dic_key.split("_")
    grafo = csv_values[0]
    analise = csv_values[1]
    ht = csv_values[3] == 'True'
    bind = csv_values[4]

    filtro = (df["GRAPH_NAME"] == grafo) & (df["ANALYSIS_TYPE"] == analise) & (df["DISABLE_HYPERTHREADING"] == ht) & (df["THREAD_BIND_POLICY"] == bind)
    df_sequencial = df[filtro & (df["THREADS"] == 1)]

    # O tempo sequencial é o ELAPSED_TIME da configuração com 1 thread
    tempo_sequencial = df_sequencial["ELAPSED_TIME"].values[0]
    
    # Atualizar SEQUENTIAL_TIME para todas as configurações desta combinação (grafo, analise, ht, bind)
    df.loc[filtro, "SEQUENTIAL_TIME"] = tempo_sequencial
    
    df.to_csv("unified_results.csv", sep=",", index=False)

def add_tempo_resultados(dic_key, tempo, contador_runs):
    csv_values = dic_key.split("_")
    grafo = csv_values[0]
    analise = csv_values[1] 
    threads = int(csv_values[2])
    ht = csv_values[3] == 'True'
    bind = csv_values[4]
    df = pd.read_csv("unified_results.csv", sep=",")
    filtro = (df["GRAPH_NAME"] == grafo) & (df["ANALYSIS_TYPE"] == analise)  & (df["THREADS"] == threads) & (df["THREAD_BIND_POLICY"] == bind) & (df["DISABLE_HYPERTHREADING"] == ht)

    # Usar média ponderada correta
    tempo_atual = df.loc[filtro, "ELAPSED_TIME"].values[0]
    if tempo_atual == 0.0:
        # Primeiro valor
        df.loc[filtro, "ELAPSED_TIME"] = float(tempo)
    else:
        # Calcular média correta: (soma_anterior + novo_valor) / total_runs
        # soma_anterior = tempo_atual * (contador_runs - 1)
        soma_anterior = tempo_atual * (contador_runs - 1)
        nova_soma = soma_anterior + float(tempo)
        nova_media = nova_soma / contador_runs
        df.loc[filtro, "ELAPSED_TIME"] = nova_media

    df.to_csv("unified_results.csv", sep=",", index=False)

def calcular_speedup_parallel_efficiency(dic_key):
    csv_values = dic_key.split("_")
    threads = int(csv_values[2])
    grafo = csv_values[0]
    analise = csv_values[1]
    ht = csv_values[3] == 'True'
    bind = csv_values[4]
    df = pd.read_csv("unified_results.csv", sep=",")
    filtro = (df["GRAPH_NAME"] == grafo) & (df["ANALYSIS_TYPE"] == analise)  & (df["THREADS"] == threads) & (df["THREAD_BIND_POLICY"] == bind) & (df["DISABLE_HYPERTHREADING"] == ht)
    
    sequential_time = df.loc[filtro, "SEQUENTIAL_TIME"].values[0]
    elapsed_time = df.loc[filtro, "ELAPSED_TIME"].values[0]
    speed_up = sequential_time / elapsed_time
    parallel_efficiency = sequential_time / (threads * elapsed_time)

    df.loc[filtro, "SPEEDUP"] = speed_up
    df.loc[filtro, "PARALLEL_EFFICIENCY"] = parallel_efficiency

    df.to_csv("unified_results.csv", sep="," , index=False)


def main():
    t0 = time.time()
    # Copia o arquivo experiments.csv para unified_results.csv
    subprocess.run(["cp", "experiments.csv", "unified_results.csv"])
    df_unified = pd.read_csv("unified_results.csv", sep=",")
    # Adiciona as colunas que conterão nossos resultados
    df_unified["ELAPSED_TIME"] = float(0.0)
    df_unified["SPEEDUP"] = float(0.0)
    df_unified["PARALLEL_EFFICIENCY"] = float(0.0)
    df_unified["SEQUENTIAL_TIME"] = float(0.0)
    df_unified.to_csv("unified_results.csv", sep=",", index=False)

    # Pega todos os arquivos report.csv
    all_csv = subprocess.run([
        "find", 
        ".", 
        "-regex", 
        ".*/results/.*/run-.*/report.csv"
    ], capture_output=True, text=True, check=True)

    lista_arquivos = all_csv.stdout.strip().split('\n')

    # 3780
    print(f'Quantidade de arquivos de resultados: {len(lista_arquivos)}')
    
    # Contar runs por configuração
    contador_runs = {}
    
    for arquivo in lista_arquivos:
        arquivo = arquivo[2::]
        arquivo_dir = arquivo.split("/")[1::]
        grafo = arquivo_dir[0]
        analise = arquivo_dir[1]
        threads = int(arquivo_dir[2].split("-")[1])
        ht_str = arquivo_dir[3].split("-")[1]
        ht = ht_str == 'true'
        bind = arquivo_dir[4].split("-")[1]
        dic_key = f'{grafo}_{analise}_{threads}_{ht}_{bind}'
        
        # Contar este run
        if dic_key not in contador_runs:
            contador_runs[dic_key] = 0
        contador_runs[dic_key] += 1
        
        df = pd.read_csv(arquivo, sep='\t', engine='python', header=0, on_bad_lines="skip")
        
        if(analise == 'hpc-performance'):
            tempo = df[df["Metric Name"] == "Elapsed Time"]["Metric Value"].values[0]
        elif(analise == 'hotspots'):
            tempo = df[df["Metric Name"] == "Elapsed Time"]["Metric Value"].values[0]
        elif(analise == 'performance-snapshot'):
            tempo = df[df["Metric Name"] == "Elapsed Time"]["Metric Value"].values[0]

        add_tempo_resultados(dic_key, tempo, contador_runs[dic_key])

    # Calcular sequential time após processar todos os elapsed times
    for dic_key in contador_runs:
        csv_values = dic_key.split("_")
        threads = int(csv_values[2])
        if threads == 1:
            setSequencialTime(dic_key)

    # Calcular speedup e parallel efficiency
    for dic_key in contador_runs:
        calcular_speedup_parallel_efficiency(dic_key)

    t1 = time.time()
    print(f"Tempo de execução: {t1 - t0} segundos")

if __name__ == "__main__":
    main()

