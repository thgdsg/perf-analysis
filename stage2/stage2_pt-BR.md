# Anotações Etapa 2 Análise de Desempenho

Criamos o executa_bench.sh, nosso script que faz as seguintes coisas:
1. Baixa o grafo dado o link de download, que no nosso caso é do repositório Stanford Large Network Dataset Collection.
2. Converte pro padrão de entrada do benchmark
3. Executa o benchmark com os parâmetros passados dentro do código
4. Salva os logs em uma pasta "logs"
// TODO - transformar o script em um que rode várias vezes com vários números de threads, e integre o Intel VTune Profiler na execução

Os parâmetros decididos foram:
- Máximo de 50 iterações, pois garante que o algoritmo vai executar até os valores calculados ficarem dentro da tolerância desejada (estabilizarem).
- Tolerância de 1e-4, padrão utilizado pelo GAP benchmark.
- Quantidade de Threads definida em { 1, 4, 12, 22, 28, 36, 44, 66, 88 }, comentaremos mais sobre isso na escolha do ambiente de execução.
- Vamos utilizar o governor DVFS performance.
- O benchmark só deve ser feito caso a temperatura do processador esteja menor que 30 graus celsius.

Decidimos que vamos utilizar a máquina do PCAD "blaise", pois ela possui dois processadores Intel(R) Xeon(R) E5-2699 v4, com 22 Cores cada que rodam com frequências base de 2.20GHz.

Quanto ao Intel VTune, pretendemos utilizar os seguintes tipos de análise disponíveis pela aplicação:
- **performance-snapshot**:
    - O que mede: visão ampla do sistema e do processo (CPU util., tempo de espera, memória/NUMA, I/O, GPU, threads, top hotspots, recomendações).
    - Quando usar: primeiro diagnóstico/triagem para entender onde focar (CPU vs memória vs I/O).
    - Overhead: baixo a moderado; execução curta recomendada.
    - Saída: resumo com “bottleneck categories” e links sugerindo a próxima análise.

- **hpc-performance**:
    - O que mede: caracterização de aplicações HPC (OpenMP/MPI): eficiência de paralelismo, balanceamento, intensidade de vetor, bound compute/memória, roofline, memória/NUMA, BW.
    - Quando usar: apps paralelas (muitos threads ou MPI). Mesmo em 1 CPU, útil para saber se o kernel está memory-bound e o nível de vetor/IPC.
    - Overhead: moderado; usa mais contadores de HW.
    - Saída: resumo HPC, roofline, breakdown compute vs memory bound, métricas de paralelismo (OpenMP/MPI).

Além disso, decidimos que vamos utilizar **apenas uma CPU**, pra evitar problemas e variação na comunicação entre CPUs, tornando nossos resultados mais consistentes.