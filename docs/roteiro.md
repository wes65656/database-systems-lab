# Roteiro de aprendizado

| Experimento | Pergunta | O que observar |
| --- | --- | --- |
| 01 — ACID | Uma falha deixa metade da transferência gravada? | COMMIT, ROLLBACK, SAVEPOINT |
| 02 — Isolamento | Duas leituras da mesma linha podem mudar? | Snapshots e níveis de isolamento |
| 03 — Concorrência | Duas compras podem vender uma única unidade? | Race condition e atualização atômica |
| 04 — Índices | Um índice composto muda o plano de execução? | Seq Scan, Index Scan, buffers e latência |
| 05 — Partições | A consulta precisa olhar todas as tabelas físicas? | Partition pruning no plano |

## Como registrar os resultados

Para cada experimento, registre:

1. **Hipótese:** o que você imagina que aconteça?
2. **Setup:** versão do PostgreSQL, ambiente e volume de dados.
3. **Procedimento:** comandos executados.
4. **Resultado:** saída SQL, plano de execução ou contagem.
5. **Interpretação:** por que aconteceu? Quais limitações?

Não invente benchmarks. Resultados variam conforme computador, cache, volume e concorrência.

## Extensões futuras (opcionais)

- Optimistic concurrency token e detecção de conflitos.
- Deadlocks e ordem dos bloqueios.
- OFFSET versus keyset pagination.
- MVCC, VACUUM e visibilidade de versões.
- WAL, backup lógico e recuperação.
- Read-heavy/write-heavy com gerador de carga.
- Replicação, lag e sharding.

Cada experimento deve permanecer independente e pequeno.
