# 🎓 Thanwya Results API

A highly optimized, lightweight, **read-only** REST API designed to serve **Thanaweya Amma (Egyptian High School) results** at extreme scale. 

By leveraging **Slim PHP 4**, an optimized **SQLite** database, and **FrankenPHP's Worker Mode**, this application scales from a standard baseline of **500 Requests Per Second (RPS)** under Nginx + PHP-FPM to an astonishing **15,000+ RPS**—a **30x increase in performance** using the exact same hardware limits.

---

## ⚡ Performance Journey: 500 RPS to 15,000+ RPS

The API was engineered through two distinct phases to explore the absolute limits of PHP performance.

### Phase 1: Standard Nginx + PHP-FPM (`~500 RPS`)
* **Setup:** Nginx acts as a reverse proxy forwarding requests to a PHP-FPM 8.3 pool.
* **Bottleneck:** Standard PHP execution models boot up the entire framework (routing, container, autoloader, database connection) from scratch for *every single incoming HTTP request*. Under load, this introduces extreme process-management overhead, context-switching, and file I/O latency.
* **Result:** Reached a peak of around **500 requests per second** before hitting high latencies and CPU limits.

### Phase 2: FrankenPHP in Worker Mode (`15,000+ RPS`) 🚀
* **Setup:** Built on top of **FrankenPHP** (powered by Caddy) with **Worker Mode** enabled.
* **How it works:** 
  Instead of killing the PHP process after each request, FrankenPHP spawns **persistent workers** (4 workers configured in `Caddyfile`).
  - The Slim PHP framework, Dependency Injection container, and SQLite PDO database connection are **bootstrapped once** in memory when the worker starts.
  - An event loop (`frankenphp_handle_request`) intercepts incoming requests and passes them directly to the pre-loaded application instance.
  - Memory leak prevention is handled via garbage collection cycles every 100 requests.
* **Result:** Achieved **over 15,000 requests per second** under the same resource limitations (**2.0 CPUs, 1GB RAM** limit), yielding a **30x throughput gain** and sub-millisecond latencies!

---

## 💾 Read-Only SQLite Optimization

Because this API is strictly **read-only** (serving pre-published grades without any runtime write queries), the database layer is highly optimized for fast, zero-network-overhead disk reads. 

By utilizing **SQLite**, we eliminate the network TCP roundtrip overhead of dedicated database servers (like MySQL or PostgreSQL). The database is optimized directly through PDO with the following settings:

```php
$options = [
    PDO::SQLITE_ATTR_OPEN_FLAGS => PDO::SQLITE_OPEN_READONLY, // Open in read-only mode
    PDO::ATTR_ERRMODE           => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE=> PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES  => false,
    PDO::ATTR_PERSISTENT        => true,                      // Persistent connection
];

$pdo = new PDO('sqlite:database.sqlite', options: $options);
$pdo->exec("
    PRAGMA journal_mode = WAL;          -- Write-Ahead Logging for concurrency
    PRAGMA synchronous = OFF;           -- Offloads disk-sync wait (extremely safe for read-only)
    PRAGMA query_only = ON;             -- Enforces read-only at the database level
    PRAGMA cache_size = -64000;         -- Allocates ~64 MB of RAM for database page caching
");
```

---

## 🛠️ Project Structure

```bash
├── public/
│   ├── index.php         # FrankenPHP entrance (with worker loop)
│   └── index-fpm.php     # PHP-FPM entrance (standard request cycle)
├── setup/
│   ├── caddy/
│   │   └── Caddyfile     # FrankenPHP & Worker Mode definitions
│   ├── fpm/
│   │   ├── php-fpm.conf  # Master FPM configuration
│   │   └── www.conf      # Custom tuned FPM process pool
│   ├── nginx/
│   │   └── docker.conf   # Nginx server configuration
│   └── php/
│       └── php.ini       # Customized production PHP config
├── storage/
│   └── database/
│       └── database.sqlite # SQLite database containing results
├── Dockerfile            # PHP-FPM & Nginx Dockerfile
├── Dockerfile.frank      # FrankenPHP Dockerfile
├── docker-compose.yml    # Main compose file (FrankenPHP)
└── docker-compose-fpm.yml# Alternative compose file (Nginx + PHP-FPM)
```

---

## 🚀 Getting Started

### 1. Run the FrankenPHP High-Performance Version (Default)
This builds the FrankenPHP image and mounts the persistent workers, ready to handle 15,000+ RPS.

```bash
# Start the containers
docker compose up --build -d

# Check the running services
docker compose ps
```
The API is now running on **`http://localhost:8080`**.

### 2. Run the Nginx + PHP-FPM Version (Comparison Setup)
To run the traditional setup for benchmarking or comparison:

```bash
# Start the FPM + Nginx stack
docker compose -f docker-compose-fpm.yml up --build -d
```
The FPM API is now running on **`http://localhost:8080`**.

---

## 📡 API Usage

### Retrieve Results by Seat Number

**Request:**
`GET http://localhost:8080/results?seat_no=<seat_number>`

**Example CURL:**
```bash
curl -i "http://localhost:8080/results?seat_no=123456"
```

**Example Response:**
```json
{
    "data": {
        "id": 2001979,
        "student_name": "مصطفي محمد عبدالراضي رشيدي حسين",
        "total_degree": 258.5,
        "student_case": "ناجح دور أول"
    }
}
```

*Note: If `seat_no` is missing or not found, a `404 Not Found` JSON error response is returned.*

---

## 🔬 Benchmark Comparison Details

We performed stress-testing using `wrk` with **12 threads and 400 concurrent connections over 30 seconds**, using a custom Lua script to simulate realistic query traffic (`benchmark.lua`):

```bash
wrk -t12 -c400 -d30s -s benchmark.lua http://localhost:8080
```

### 📊 Performance Summary (400 Concurrent Connections)

| Metric | Traditional Nginx + PHP-FPM | FrankenPHP (Worker Mode) 🚀 | Performance Multiplier |
| :--- | :--- | :--- | :--- |
| **Throughput (RPS)** | **198.00** requests/sec | **16,066.99** requests/sec | **81.1x Faster** |
| **Total Requests (30s)** | 5,952 | **482,745** | **81.1x more requests handled** |
| **Avg Latency** | 899.73 ms | **58.06 ms** | **93.5% Latency Reduction** |
| **Max Latency** | 2.00 s (timeout threshold) | **1.07 s** | - |
| **50% Latency (Median)** | 854.16 ms | **21.85 ms** | **97.4% Latency Reduction** |
| **90% Latency** | 1.74 s | **36.60 ms** | **97.9% Latency Reduction** |
| **Socket Timeouts** | 2,668 (44.8% of requests) | **6 (0.001% of requests)** | **99.7% Timeout Reduction** |
| **Total Transfer** | 2.59 MB | **81.95 MB** | - |

---

### 📝 Detailed Raw Benchmark Logs

<details>
<summary><b>Click to expand Nginx + PHP-FPM wrk Output</b></summary>

```text
Running 30s test @ http://localhost:8080
  12 threads and 400 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   899.73ms  513.12ms   2.00s    58.59%
    Req/Sec    26.74     35.61   230.00     89.50%
  Latency Distribution
     50%  854.16ms
     75%    1.33s 
     90%    1.74s 
     99%    1.92s 
  5952 requests in 30.06s, 2.59MB read
  Socket errors: connect 0, read 0, write 0, timeout 2668
Requests/sec:    198.00
Transfer/sec:     88.28KB
```

</details>

<details>
<summary><b>Click to expand FrankenPHP (Worker Mode) wrk Output</b></summary>

```text
Running 30s test @ http://localhost:8080
  12 threads and 400 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    58.06ms  148.39ms   1.07s    94.20%
    Req/Sec     1.35k   178.05     1.77k    75.03%
  Latency Distribution
     50%   21.85ms
     75%   25.30ms
     90%   36.60ms
     99%  882.73ms
  482745 requests in 30.05s, 81.95MB read
  Socket errors: connect 0, read 0, write 0, timeout 6
Requests/sec:  16066.99
Transfer/sec:      2.73MB
```

</details>

---

### 🔍 Bottleneck Analysis & Explanation

Under a high concurrency load of **400 connections**, the performance gap grows to a mind-blowing **81x**. Here is why:

1. **Worker Pool & Queuing Exhaustion (PHP-FPM):**
   In standard PHP-FPM, each incoming request requires a dedicated PHP process. Because our concurrent connections (400) far exceed the FPM process pool capacity, incoming requests are queued. This queuing delay adds massive latency before the script even executes, leading to **2,668 timeouts** (45% of total requests) as requests hit `wrk`'s default 2-second timeout.
2. **Bootstrapping Overhead (PHP-FPM):**
   The FPM workers that do process requests must bootstrap the Slim framework, set up dependency injection, read configuration files, and re-establish a PDO SQLite database connection on *every single request*. This prevents FPM from scaling past **~198 RPS** under high stress.
3. **Persisted Workers & Event Loop (FrankenPHP):**
   In FrankenPHP's Worker Mode, persistent workers are spawned once on start. The framework, routing, containers, and PDO connections are bootstrapped **once in memory**. The worker loop uses `frankenphp_handle_request()` to intercept HTTP requests from the underlying Caddy engine, bypassing almost all I/O and setup overhead. This allows the system to sustain **16,066.99 RPS** with **sub-60ms average latency** and virtually **zero timeouts (only 6 out of 480k+ requests)** under the exact same system resources!

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
