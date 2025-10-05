# Anotações Etapa 2 Análise de Desempenho pré-execução

Criamos o executa_bench.sh, nosso script que faz as seguintes coisas:
1. Baixa o grafo dado o link de download, que no nosso caso é do repositório Stanford Large Network Dataset Collection.
2. Converte pro padrão de entrada do benchmark
3. Executa o benchmark com os parâmetros passados dentro do código
4. Salva os logs em uma pasta "logs"
5. Salva os resultados em uma pasta "results"

Os parâmetros decididos foram:
- ~~Máximo de 50 iterações, pois garante que o algoritmo vai executar até os valores calculados ficarem dentro da tolerância desejada (estabilizarem).~~
- ~~Tolerância de 1e-4, padrão utilizado pelo GAP benchmark.~~
- Máximo de 500 iterações, pra garantir um tempo mínimo de execução e maior *stress* na CPU.
- Tolerância de 1e-6, pra garantir que o máximo de iterações será atingido.
- Quantidade de Threads definida em { 1, 4, 12, 22, 28, 36, 44, 66, 88 }, comentaremos mais sobre isso na escolha do ambiente de execução.
- Vamos utilizar o governor DVFS performance.
- Vamos ver como fica a diferença na execução com o HyperThreading e sem.
- Vamos ver como a política de "binding" de threads afeta a execução dos programas.

## Escolha do Ambiente de Execução
Decidimos que vamos utilizar a máquina do PCAD "blaise", pois ela possui dois processadores Intel(R) Xeon(R) E5-2699 v4, com 22 Cores cada que rodam com frequências base de 2.20GHz. Cada um dos processadores possui 44 Threads, das quais 22 são físicas e 22 lógicas.

Vamos utilizar as duas CPUs com o governor performance mas sem limitar frequências, e vamos ver também como que fica a média de frequência da CPU durante a execução.

~~Vamos utilizar uma flag do OpenMP chamada "GOMP_CPU_AFFINITY="0-21 44-65", que significa que o socket 0 utiliza as threads 0-21 e 44-65 do computador.~~

Vamos utilizar o "taskset" pra definir se o hyperthreading ficará ligado ou desligado (essencialmente colocando 1 thread por core se estiver desligado e 2 threads por core se estiver ligado).

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

- **hotspots**:
- O que mede: tempo de CPU por função/arquivo/linha, uso de CPU ao longo do tempo, pilhas de chamadas, divisão user/kernel, e (opcional) eventos de HW.
- Quando usar: primeira análise focada no código. Serve para localizar funções críticas, laços não vetorizados, spin/wait e regressões.
- Como funciona: amostragem por interrupções (baixa sobrecarga). Com símbolos (-g) mostra nomes de funções e linhas; com PGO/strip pode precisar de -fno-omit-frame-pointer para melhores stacks.
- O que olhar:
    - Top Functions/Call Tree: funções com maior CPU Time e seus callers/callees.
    - Source/Assembly: linhas críticas e possíveis gargalos (branching, falta de vetor).
    - Timeline: saturação da CPU e fases do programa.
- Integração com OpenMP: mostra regiões paralelas, desequilíbrio entre threads e tempo gasto em runtimes/barreiras.

