# E-commerce Scale Lab

Experimento independente dentro do [Database Systems Lab](../../README.md). O objetivo é investigar o que muda quando uma **base de e-commerce cresce de milhares para dezenas de milhões de registros**. Primeiro usamos tabelas relacionais tradicionais, depois medimos consultas, aplicamos índices e comparamos com uma cópia particionada.

**Não reescreve nem altera o laboratório original** na raiz do repositório. Usa outro PostgreSQL, outro banco, outro volume Docker e outra porta.

> **Status:** código e SQL preparados para execução. Ainda não foi realizada validação com Docker nem medidos tempos reais nesta publicação; execute localmente e registre seus resultados.

## Estrutura

```text
labs/ecommerce-scale/
├── .gitignore
├── docker-compose.yml           # PostgreSQL isolado, porta 5434
├── scripts/
│   ├── setup.ps1                # Gera dataset pequeno ou completo
│   ├── compare.ps1              # Baseline e comparação com índices
│   └── partition.ps1            # Cópia por mês + EXPLAIN
├── sql/
│   ├── 00_schema.sql            # 6 tabelas relacionais convencionais
│   ├── 01_seed.sql              # Dados determinísticos
│   ├── 02_validate.sql          # Contagens e integridade
│   ├── 03_baseline_queries.sql  # EXPLAIN (ANALYZE, BUFFERS)
│   ├── 04_remove_indexes.sql    # Prepara benchmark sem índices extras
│   ├── 04_add_indexes.sql       # Índices otimizados
│   ├── 05_partitioned_copy.sql  # 24 partições de pedidos (2024–2025)
│   └── 06_partition_comparison.sql
└── docs/
    └── experimentos.md          # Roteiro e método de medição
```

## Pré-requisitos

- Docker Desktop iniciado, com Docker Compose.
- PowerShell 7 para os scripts de automação (ou execute os SQLs pelo `psql` manualmente).
- Espaço em disco. A **carga completa** pode ocupar muitos GB adicionais e exigir tempo de processamento; o volume varia por máquina e configuração.

Banco exclusivo deste laboratório: `ecommerce_scale`, usuário `scale_lab`, senha **apenas para desenvolvimento local** `scale_dev_only`. Porta `127.0.0.1:5434`. Não exponha essas credenciais publicamente.

## Começando pelo tamanho pequeno

No PowerShell 7, a partir da **raiz do repositório**:

```powershell
cd labs/ecommerce-scale
./scripts/setup.ps1
```

O script inicia o Docker, aplica o esquema, gera dados e verifica contagens. Tamanho padrão:

| Tabela | Pequena | Completa |
| --- | ---: | ---: |
| categories | 100 | 100 |
| customers | 10.000 | 1.000.000 |
| products | 500 | 50.000 |
| orders | 50.000 | 5.000.000 |
| order_items | 150.000 | 15.000.000 |
| payments | 50.000 | 5.000.000 |
| **Total** | **260.600** | **26.050.100** |

Valores são **metas de geração**, não quantidades verificadas em execução. A geração é determinística: cada pedido possui três itens, cada pedido um pagamento e todas as referências apontam para registros existentes.

Para executar manualmente um SQL:

```powershell
docker compose exec db psql -U scale_lab -d ecommerce_scale -v ON_ERROR_STOP=1 -f /lab/sql/02_validate.sql
```

## Teste de índices: medir antes e depois

```powershell
./scripts/compare.ps1 -AddIndexes
```

Esse script:

1. Remove apenas os índices extras do experimento, preservando PKs e constraints.
2. Mede as consultas originais sem esses índices.
3. Cria os índices adicionais.
4. Executa novamente as mesmas consultas.
5. Salva `results/baseline.txt` e `results/after-indexes.txt`.

A pasta `results/` fica fora do controle de versão para evitar publicar resultados descontextualizados. Compare plano de execução, buffers e tempos em várias rodadas: uma execução isolada não é benchmark confiável.

## Teste de particionamento: cópia sem substituir a tabela original

```powershell
./scripts/partition.ps1
```

Esse script cria `orders_partitioned`, uma **segunda tabela** com 24 partições mensais, copia os pedidos existentes e compara consultas por intervalo de datas com `orders`.

- `orders` permanece sem particionamento.
- `order_items` e `payments` continuam apontando para `orders`.
- A cópia particionada serve somente para o experimento de leitura; **não** integra o fluxo transacional do e-commerce.
- O script recria apenas `orders_partitioned` e seu conteúdo, para permitir repetir a experiência.
- O particionamento não equivale a sharding. Ainda estamos em um único PostgreSQL.

**Cuidado:** a cópia exige espaço adicional, especialmente com 5 milhões de pedidos. O ganho de desempenho não é garantido; o sinal mais importante é o *partition pruning* no `EXPLAIN`.

## Carga completa — execução explícita

**Use apenas quando a carga pequena estiver funcionando e houver disco/memória disponíveis.**

```powershell
./scripts/setup.ps1 -Size full
```

Isso reinicia as **seis tabelas deste banco de laboratório** (`TRUNCATE`) e gera os 26.050.100 registros. Não atinge o banco original do repositório. Como os dados são recriados, execute os testes de índices **depois** da carga escolhida.

O comando padrão sem `-Size full` nunca deve disparar esse volume.

## O que estudar

- **Relacionamentos:** PK, FK, UNIQUE, CHECK e custo de manter integridade em larga escala.
- **Consultas:** filtro por cliente, itens por pedido e agregação por categoria.
- **Índices:** planos de execução antes/depois, custo de índices e seletividade.
- **Partitioning:** diferenças entre tabelas comuns e particionadas por mês.
- **Arquitetura:** por que sharding e replicação precisam ser experimentos futuros separados.

Consulte o [roteiro](docs/experimentos.md) para registrar hipóteses, medições, resultados e limitações.

## Encerrar ou zerar

```powershell
docker compose down
```

Para apagar **somente o volume de dados deste laboratório**:

```powershell
docker compose down -v
```

**Atenção:** `down -v` apaga os dados persistidos do PostgreSQL deste laboratório.

## Referências

- [PostgreSQL: Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [PostgreSQL: EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html)
- [PostgreSQL: Indexes](https://www.postgresql.org/docs/current/indexes.html)
- [PostgreSQL: Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html)
