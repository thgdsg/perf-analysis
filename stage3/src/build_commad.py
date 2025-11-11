# This module creates the build command for the benchmark
# 1. Reads the CSV file
# 2. Creates the build command for the benchmark
# 3. Creates a file with the commands

import csv

csv_file = "./experiments_noHT.csv"

def create_build_commands(csv_file):
    commands = []
    with open(csv_file, 'r') as file:
        reader = csv.reader(file)
        header = next(reader)
        for row in reader:
            graph_name = row[header.index("GRAPH_NAME")]
            graph_url = row[header.index("GRAPH_URL")]
            threads = row[header.index("THREADS")]
            max_iters = row[header.index("MAX_ITERS")]
            tolerance = row[header.index("TOLERANCE")]
            analysis_type = row[header.index("ANALYSIS_TYPE")]
            disable_hyperthreading = row[header.index("DISABLE_HYPERTHREADING")].strip()
            thread_bind_policy = row[header.index("THREAD_BIND_POLICY")].strip()
            logs_gapbs = row[header.index("LOGS_GAPBS")].strip()
            vtune_enable = row[header.index("VTUNE_ENABLE")].strip()

            # Loop para criar 5 execuções para cada linha do CSV
            for i in range(1, 6):
                command = (
                    f"./src/executa_bench.sh "
                    f"-graph-name {graph_name} "
                    f"-graph-url {graph_url} "
                    f"-threads {threads} "
                    f"-max-iters {max_iters} "
                    f"-tolerance {tolerance} "
                    f"-analysis-type {analysis_type} "
                    f"-disable-hyperthreading {disable_hyperthreading} "
                    f"-thread-bind-policy {thread_bind_policy} "
                    f"-vtune-enable {vtune_enable} "
                    f"-run-id {i}"  # Adiciona o ID da execução
                )

                if logs_gapbs.lower() == 'true':
                    command += " -gap-logs"

                commands.append(command)
    return commands


if __name__ == "__main__":
    commands = create_build_commands(csv_file)
    commands_formatted = ' && \n'.join(commands)
    
    # Cria arquivo com os comandos formatados
    with open('./src/commands.sh', 'w') as f:
        f.write(commands_formatted)


