# Lab 04 — Performance e diagnóstico

Use planos de execução, contadores de carga e esperas do PostgreSQL 18 para explicar por que uma consulta acessa muitos blocos, usa disco temporário ou fica bloqueada. O laboratório cria 60 mil eventos determinísticos em um banco e volume Docker próprios.

## Executar

Na pasta `labs/performance-diagnostics`, com Docker Compose e PowerShell 7:

```powershell
docker compose up -d --wait
./check.ps1
docker compose down
```

O script para na primeira falha e recria a tabela `perf_lab.events` a cada execução. Rode somente uma instância da verificação por vez. O banco `performance_diagnostics` fica dentro do contêiner, sem porta publicada. Use o usuário `lab` desse ambiente para acessar os diagnósticos. O volume conserva os dados após `down`.

Depois da preparação, é possível executar um experimento individualmente. Por exemplo:

```powershell
docker compose exec -T db psql -X -U lab -d performance_diagnostics -f /lab/sql/00_setup.sql
docker compose exec -T db psql -X -U lab -d performance_diagnostics -f /lab/sql/01_index.sql
```

## Experimentos

1. **Índice composto.** Compare a mesma busca dos 20 eventos mais recentes de um tenant antes e depois do índice `(tenant_id, id DESC)`. Verifique o índice escolhido, a igualdade dos resultados e a redução em blocos compartilhados acessados. A soma de hits e reads conta acessos a buffers, inclusive acessos repetidos, e não mede leituras físicas de disco.
2. **Estimativas do planejador.** Altere a distribuição de uma coluna e compare `Plan Rows` com `Actual Rows`. Rode `ANALYZE` e verifique se o erro de estimativa diminuiu. O cenário usa tabela temporária para controlar quando as estatísticas são atualizadas.
3. **Ordenação em disco.** Ordene 25 mil linhas com `work_mem` de 64 kB e de 32 MB. Compare `Sort Method`, `Sort Space Type` e blocos temporários. O limite vale por operação, e uma consulta pode ter várias operações ou processos. O ajuste fica restrito à sessão.
4. **Carga agregada.** Use `pg_stat_statements` para ordenar as consultas pelo tempo acumulado e comparar chamadas, média, linhas e blocos. Três execuções com valores diferentes aparecem sob uma assinatura normalizada. A medição zera os contadores dessa base de laboratório e inclui apenas consultas executadas durante o exercício.
5. **Sessões bloqueadas.** A primeira sessão atualiza uma linha e mantém a transação aberta. Uma segunda tenta atualizar a mesma linha. A terceira confirma a espera em `pg_stat_activity`, identifica o bloqueador com `pg_blocking_pids()` e inspeciona o lock pendente em `pg_locks`. O observador cancela a segunda atualização e a primeira sessão faz rollback. A mensagem de cancelamento do cliente bloqueado faz parte do teste.

## Como ler as medições

Em `EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)`, compare primeiro o caminho de acesso, linhas estimadas e reais, e blocos. `ANALYZE` no `EXPLAIN` executa a consulta. `TIMING OFF` desativa a cronometragem por nó e mantém o tempo total. Os tempos e a proporção de hits e reads variam com a máquina, a concorrência, o cache do PostgreSQL e o do sistema operacional. As verificações comparam resultados e efeitos observáveis sem fixar limites de latência.

Use o tempo total acumulado para encontrar consultas que mais contribuem para a carga, a média para comparar o custo por chamada e as esperas para distinguir tempo bloqueado de trabalho do plano. `pg_stat_statements` agrega execuções e não fornece percentis de latência.

## Resultados observados

Em 25 de novembro de 2026, todas as verificações passaram no PostgreSQL 18.7, com blocos de 8 KiB e 60 mil eventos.

- **Índice composto.** Os mesmos 20 eventos exigiram 161 acessos a buffers compartilhados antes e 22 depois. O plano passou de uma varredura reversa da chave primária, com filtro do tenant, para uma busca no índice composto.
- **Estimativas.** O planejador estimou 1.547 linhas, embora a consulta encontrasse 9.000. Após ANALYZE, a estimativa passou para 9.000.
- **Ordenação.** Com 64 kB, o sort externo gravou 2.689 blocos temporários. Com 32 MB, o quicksort rodou em memória e gravou zero blocos temporários.
- **Carga agregada.** As três consultas por categoria foram agrupadas em uma entrada com três chamadas.
- **Bloqueios.** O observador identificou uma espera do tipo Lock no evento transactionid. A sessão bloqueadora aparecia como idle in transaction.


## Referências

- [PostgreSQL 18 — Using EXPLAIN](https://www.postgresql.org/docs/18/using-explain.html)
- [PostgreSQL 18 — pg_stat_statements](https://www.postgresql.org/docs/18/pgstatstatements.html)
- [PostgreSQL 18 — Monitoring Database Activity](https://www.postgresql.org/docs/18/monitoring-stats.html)
- [PostgreSQL 18 — pg_locks](https://www.postgresql.org/docs/18/view-pg-locks.html)
