# Plano dos experimentos de escala

Este laboratório começa com **um único PostgreSQL e seis tabelas não particionadas**. A ideia é medir antes de mudar a arquitetura.

## Experimento A — esquema e volume

1. Execute o script de esquema e o gerador de dados no tamanho pequeno.
2. Rode `02_validate.sql` e confira que um pedido tem três itens e um pagamento.
3. Observe PK, FK, UNIQUE, CHECK e cardinalidade das tabelas.
4. A carga completa deve ser iniciada explicitamente; ela pode consumir muitos GB e demorar bastante.

## Experimento B — sem índices adicionais

1. Execute `03_baseline_queries.sql`.
2. Guarde os resultados do `EXPLAIN (ANALYZE, BUFFERS)`.
3. Registre estimativas de linhas, linhas reais, leituras de buffer e tempo.
4. Não conclua que todo `Seq Scan` é ruim: tabelas pequenas e queries pouco seletivas podem favorecer esse plano.

## Experimento C — com índices adicionais

1. Rode `04_add_indexes.sql`.
2. Execute novamente as **mesmas consultas**, com o **mesmo conjunto de dados**.
3. Compare planos e tempos, repetindo cada teste para observar aquecimento de cache.
4. Considere o custo dos índices para INSERT e UPDATE, não apenas a leitura.
5. Registre o tamanho dos índices se desejar: `SELECT pg_size_pretty(pg_indexes_size('orders'));`

## Próximos experimentos (ainda não implementados)

- Comparação entre tabelas convencionais e tabelas particionadas por data.
- Partition pruning e efeitos em manutenção.
- Simulações de múltiplos shards com bancos realmente separados.
- Rebalanceamento e hot shards.
- Distribuição das leituras, replicação e consistência.

**Não trate sharding como mera criação de partições locais.** A etapa distribuída terá outro setup.

## Modelo de resultado

| Medição | Sem índice | Com índice |
| --- | --- | --- |
| Linhas do dataset | preencher | preencher |
| Plano predominante | preencher | preencher |
| Latência de execução | preencher | preencher |
| Buffers lidos | preencher | preencher |
| Tamanho de índices | preencher | preencher |

Os números só devem ser preenchidos depois de executar os experimentos.
