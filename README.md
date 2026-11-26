# Database Systems Lab 🧪

Laboratório prático e reproduzível de **engenharia de bancos de dados**.

O objetivo é observar como transações, isolamento, concorrência, índices e particionamento se comportam de verdade, com experimentos pequenos e independentes. Sem API, DDD, Clean Architecture ou SDD: apenas **PostgreSQL + Docker + Console C#/.NET 10**.

> **Estado:** exercícios preparados e versionados, mas ainda não executados/validados neste ambiente. Resultados de desempenho não são inventados. Execute localmente para medir e verificar.

## Laboratórios disponíveis

Os laboratórios usam ambientes independentes, com bancos e volumes Docker próprios. O laboratório original fica na raiz.

| Laboratório | Foco | Banco local |
| --- | --- | --- |
| **01 — Fundamentos** (raiz) | ACID, isolamento, concorrência, índices e particionamento didático | `database_lab` na porta `5433` |
| **02 — E-commerce em escala** | 26 milhões de registros opcionais, consultas, otimização, partições mensais e comparações | `ecommerce_scale` na porta `5434` |
| **[03 — Storage Engines](labs/storage-engines/README.md)** | B-Tree, LSM-Tree, MVCC, VACUUM, WAL e checkpoints | `storage_engines` via Docker Compose |

➡️ **[Abrir o novo laboratório E-commerce Scale](labs/ecommerce-scale/README.md)**

Comece com a carga pequena e só execute os 26 milhões de registros se quiser medir a escala completa e tiver recursos disponíveis.

---

## Experimentos do laboratório original

| ID | Tema | Arquivo |
| --- | --- | --- |
| 00 | Esquema, constraints e dados iniciais | `sql/00_schema.sql` |
| 01 | ACID, COMMIT, ROLLBACK, SAVEPOINT | `sql/01_transactions.sql` |
| 02 | READ COMMITTED, REPEATABLE READ, snapshots | `sql/02_isolation.sql` e `docs/isolamento-duas-sessoes.md` |
| 03 | FOR UPDATE, atualização atômica, versionamento | `sql/03_locking.sql` |
| 04 | Índices compostos e EXPLAIN (ANALYZE, BUFFERS) | `sql/04_indexes.sql` |
| 05 | Particionamento por mês e partition pruning | `sql/05_partitioning.sql` |
| Console | Condição de corrida versus compra atômica | `src/DatabaseLab/` |

## Pré-requisitos

- Docker Desktop com engine iniciado, e Docker Compose moderno.
- SDK .NET 10 para a simulação de concorrência.
- PowerShell 7 se quiser executar o script automático.
- Rider, VS Code ou qualquer editor.

O PostgreSQL usa **porta local 5433** e credenciais de **laboratório exclusivamente local** (`lab` / `lab_dev_only`). A porta fica restrita a `127.0.0.1`. **Nunca reutilize essas credenciais em produção.**

## 1. Iniciar o banco

Na raiz do repositório:

```powershell
docker compose up -d --wait
docker compose ps
```

A imagem utilizada é `postgres:18-alpine`, com volume persistente em `/var/lib/postgresql`.

## 2. Criar o esquema

```powershell
docker compose exec db psql -U lab -d database_lab -v ON_ERROR_STOP=1 -f /lab/sql/00_schema.sql
```

Para entrar no `psql`:

```powershell
docker compose exec db psql -U lab -d database_lab
```

No `psql`: `\dt` lista tabelas, `\d products` descreve a tabela, `\q` sai.

## 3. Executar os experimentos SQL

Rode um por vez, por exemplo:

```powershell
docker compose exec db psql -U lab -d database_lab -v ON_ERROR_STOP=1 -f /lab/sql/01_transactions.sql
docker compose exec db psql -U lab -d database_lab -v ON_ERROR_STOP=1 -f /lab/sql/04_indexes.sql
```

Ou rode todos em sequência:

```powershell
./scripts/check.ps1
```

O experimento de índices cria **100 mil pedidos fictícios**; o de particionamento cria **15 mil eventos** e reinicia somente sua tabela de eventos. A demonstração de transações restaura saldos didáticos.

O experimento de isolamento em duas conexões deve ser feito **manualmente** com dois terminais, conforme [o roteiro](docs/isolamento-duas-sessoes.md).

## 4. Simulador C# — a última unidade em estoque

Cenário: um produto possui **estoque 1**, e vários compradores chegam simultaneamente.

Versão **intencionalmente incorreta**:

```powershell
dotnet run --project src/DatabaseLab -- unsafe 10
```

Todas as transações leem o mesmo estoque antes de modificar a linha. A implementação grava um valor absoluto obsoleto, simulando *lost update* e **overselling**.

Versão **correta**, com atualização condicional e inserção na mesma transação:

```powershell
dotnet run --project src/DatabaseLab -- atomic 10
```

Resultado esperado: **uma compra confirmada, uma gravada, estoque 0**.

```sql
-- Incorreto em concorrência: usa valor calculado antes do bloqueio.
UPDATE products SET stock = 0 WHERE id = 1;

-- Correto: decrementa o valor atual somente se houver estoque.
UPDATE products
SET stock = stock - 1
WHERE id = 1 AND stock > 0
RETURNING stock;
```

A atualização por si só não registra a compra; o programa C# insere em `purchases` **dentro da mesma transação**.

Cada execução redefine o estoque do produto de demonstração e remove as compras de teste. Suporta entre 2 e 20 concorrentes, com falha sinalizada por código de saída diferente de zero.

## O que medir

- **Transações:** compare estados antes e depois do COMMIT e ROLLBACK.
- **Isolamento:** compare leituras entre duas sessões.
- **Concorrência:** confirme quantas vendas foram gravadas para uma única unidade.
- **Índices:** compare planos, buffers, latência e como o cache influencia.
- **Particionamento:** identifique quais partições aparecem nos planos.

Anote hipótese, ambiente, procedimento, resultado e interpretação em [docs/roteiro.md](docs/roteiro.md).

## Organização

```text
database-systems-lab/
├── docker-compose.yml
├── src/DatabaseLab/
│   ├── DatabaseLab.csproj
│   └── Program.cs
├── sql/
│   ├── 00_schema.sql
│   ├── 01_transactions.sql
│   ├── 02_isolation.sql
│   ├── 03_locking.sql
│   ├── 04_indexes.sql
│   └── 05_partitioning.sql
├── docs/
│   ├── isolamento-duas-sessoes.md
│   └── roteiro.md
├── scripts/check.ps1
└── README.md
```

## Encerramento

```powershell
docker compose down
```

Para apagar definitivamente os dados didáticos:

```powershell
docker compose down -v
```

**Cuidado:** `down -v` remove os volumes deste projeto.

## Materiais oficiais

- [PostgreSQL: Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html)
- [PostgreSQL: Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html)
- [PostgreSQL: EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html)
- [PostgreSQL: Indexes](https://www.postgresql.org/docs/current/indexes.html)
- [PostgreSQL: Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [PostgreSQL: MVCC](https://www.postgresql.org/docs/current/mvcc.html)
- [PostgreSQL: WAL](https://www.postgresql.org/docs/current/wal-intro.html)
- [Npgsql](https://www.npgsql.org/)
- [Imagem Docker do PostgreSQL](https://hub.docker.com/_/postgres)

## Próximos experimentos

SERIALIZABLE, deadlocks, paginação por cursor, backup, cargas read-heavy/write-heavy, replicação, sharding e comparação com NoSQL.

A ideia é evoluir um experimento de cada vez. Commits representam etapas organizadas da publicação do laboratório, não registros cronológicos de desenvolvimento em dias anteriores.
