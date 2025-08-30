# 📊 Performance Analysis

**A comparative evaluation between the sequential and parallel PageRank algorithm**

*João Vitor do Amaral Spolavore, Thiago dos Santos Gonçalves*

---

## 1. Description of the Computational Object

* The **PageRank algorithm** was created by **Larry Page** and **Sergey Brin**.
* It assigns a **numerical score** to web pages based on the number and the “quality” of incoming links.
* Links from more important pages contribute more to the rank.

### Recursive definition

* The PageRank of a page is **defined recursively**, depending on the number and PageRank metric of all pages that reference it.

### Context

* Many **implementations and variations** of the PageRank algorithm exist.
* Several scientific papers analyze its efficiency.
* It was the **main algorithm used by Google** to rank web pages for years.

---

## 2. Choice of Analysis Method

* Our goal is to **compare the efficiency** of the PageRank algorithm when executed:

  * **Sequentially**
  * **In parallel using OpenMP**

* We adopted a **measurement-based approach**:

  * Measure execution time.
  * Observe the impact of parallelization.
  * Collect system metrics such as cache hits/misses and CPU usage.

### Execution Environment

* We will use computers from the **Laboratory of Parallel and Distributed Computing (PCAD)**.
* Each benchmark will be run **10 times**:

  * 5 times using **Intel® VTune™ Profiler**.
  * 5 times without the profiler (to measure execution time and energy consumption).

### Metrics to collect

* Estimated energy consumption (Watts).
* L1, L2, L3 cache hit rate (%).
* CPU usage (%).
* Additional metrics may be considered as the project advances.

### Implementation chosen

* We will use the **PageRank implementation from the GAP Benchmark Suite (GAPBS)**.
* This suite was proposed by students from **Berkeley University** and is widely used in research.

### Input graphs

* We will use datasets from the **Stanford Large Network Dataset Collection (SNAP)**.

---

## 3. Justification for Choosing PageRank

* In the course **Parallel and Distributed Programming (INF-01008)** we study different methods of algorithm parallelization.
* Therefore, we preferred to choose an algorithm we are already **familiar with**.
* This project will allow us to **combine the final works of two courses**.
* Additionally, Thiago has prior research experience in **LPPD**, working directly with PCAD and CPU metrics collection.

---

## 4. Schedule for the Next Stages

📅 **2025-09-08 to 2025-09-15 (1 week)**

* Implement PageRank parallelization using **OpenMP**.

📅 **2025-09-17 to 2025-09-29 (12 days)**

* Run benchmarks on PCAD for both sequential and parallel PageRank.

📅 **2025-10-13 to 2025-11-13 (1 month)**

* Analyze the results obtained.
* Document insights.
* Create notebooks, scripts, and plots to visualize the results.

📅 **2025-11-17 to 2025-11-23 (6 days)**

* Finalize the report.
* Organize relevant project files and artifacts.
* Submit for evaluation.

---

## 5. References

* [PageRank Algorithm Explained – Medium](https://medium.com/biased-algorithms/pagerank-algorithm-explained-5f5c6a8c6696)
* [Wikipedia – PageRank](https://en.wikipedia.org/wiki/PageRank)
* [The GAP Benchmark Suite – Arxiv](https://arxiv.org/abs/1508.03619)
* [The PageRank Algorithm and How it Works – Princeton](https://cs.wmich.edu/gupta/teaching/cs3310/lectureNotes_cs3310/Pagerank%20Explained%20Correctly%20with%20Examples_www.cs.princeton.edu_~chazelle_courses_BIB_pagerank.pdf)
* [The Anatomy of a Large-Scale Hypertextual Web Search Engine – ScienceDirect](https://www.sciencedirect.com/science/article/pii/S016975529800110X)