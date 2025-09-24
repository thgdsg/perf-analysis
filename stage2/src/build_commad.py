# This module creates the build command for the benchmark
# 1. Reads the CSV file
# 2. Creates the build command for the benchmark
# 3. Creates a file with the commands

import csv

csv_file = "./csv/experiments.csv"

def create_build_commands(csv_file):
    commands = []
    with open(csv_file, 'r') as file:
        reader = csv.reader(file)
        header = next(reader)
        for row in reader:
            graph_name = row[header.index("GRAPH_NAME")]
            graph_url = row[header.index("GRAPH_URL")]
            kernel = row[header.index("KERNEL")]
            threads = row[header.index("THREADS")]
            max_iters = row[header.index("MAX_ITERS")]
            tolerance = row[header.index("TOLERANCE")]
            logs_gapbs = row[header.index("LOGS_GAPBS")].strip()
            command = f"./src/executa_bench.sh -graph-name {graph_name} -graph-url {graph_url} -kernel {kernel} -threads {threads} -max-iters {max_iters} -tolerance {tolerance}"

            if logs_gapbs == 'true':
                command += " -gap-logs"

            commands.append(command)
    return commands


if __name__ == "__main__":
    commands = create_build_commands(csv_file)
    commands_formatted = ' && \n'.join(commands)
    
    # Cria arquivo com os comandos formatados
    with open('commands.sh', 'w') as f:
        f.write(commands_formatted)
    

