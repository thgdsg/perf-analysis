import pandas as pd
import subprocess


def add_tempo_resultados(dic_key,tempo):
    csv_values = dic_key.split("_")
    grafo = csv_values[0]
    analise = csv_values[1] 
    threads = int(csv_values[2])
    ht = csv_values[3]
    bind = csv_values[4]
    df = pd.read_csv("unified_results.csv", sep=",")

    if ht == "true":
        ht = True
    else:
        ht = False

    filtro = (df["GRAPH_NAME"] == grafo) & (df["ANALYSIS_TYPE"] == analise)  & (df["THREADS"] == threads) & (df["THREAD_BIND_POLICY"] == bind) & (df["DISABLE_HYPERTHREADING"] == ht)
    columns_df = df.columns

    # Adiciona a coluna ELAPSED_TIME se não existir
    if("ELAPSED_TIME" not in columns_df):
        df["ELAPSED_TIME"] = float(0.0)

    if(df.loc[filtro, "ELAPSED_TIME"].values[0] == 0.0):
        df.loc[filtro, "ELAPSED_TIME"] = float(tempo)
    else:
        df.loc[filtro, "ELAPSED_TIME"] = (df.loc[filtro, "ELAPSED_TIME"].values[0] + float(tempo)) / 2


    df.to_csv("unified_results.csv", sep=",", index=False)

subprocess.run(["cp", "experiments.csv", "unified_results.csv"])
# Cada parte do comando é um item separado na lista
all_csv = subprocess.run([
    "find", 
    ".", 
    "-regex", 
    ".*/results/.*/run-.*/report.csv"
], capture_output=True, text=True, check=True)

lista_arquivos = all_csv.stdout.strip().split('\n')

# 3780
print(f'Quantidade de arquivos de resultados: {len(lista_arquivos)}')

dic_tempo = {}

for arquivo in lista_arquivos:
    # remove o ./
    arquivo = arquivo[2::]
    arquivo_dir = arquivo.split("/")[1::]
    grafo = arquivo_dir[0]
    analise = arquivo_dir[1]
    threads = arquivo_dir[2].split("-")[1]
    ht = arquivo_dir[3].split("-")[1]
    bind = arquivo_dir[4].split("-")[1]
    dic_key = f'{grafo}_{analise}_{threads}_{ht}_{bind}'

    df = pd.read_csv(arquivo, sep='\t', engine='python', header=0, on_bad_lines="skip")
    
    if(analise == 'hpc-performance'):
        tempo = df[df["Metric Name"] == "Elapsed Time"]["Metric Value"].values[0]
    elif(analise == 'hotspots'):
        tempo = df[df["Metric Name"] == "Elapsed Time"]["Metric Value"].values[0]
    elif(analise == 'performance-snapshot'):
        tempo = df[df["Metric Name"] == "Elapsed Time"]["Metric Value"].values[0]

    add_tempo_resultados(dic_key,tempo)

