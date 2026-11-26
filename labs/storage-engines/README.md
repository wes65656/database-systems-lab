# Lab 03 — Storage Engines

O laboratório tem duas partes independentes. O console C# mostra os mecanismos de B-Tree e LSM-Tree com dados em memória. Os scripts SQL medem páginas, versões de linhas e registros WAL de um PostgreSQL 18 real.

## Simulação em C#

Na pasta `labs/storage-engines`, com o SDK .NET 8 instalado, execute:

```powershell
dotnet run --project simulation
dotnet run --project simulation -- --test
```

- **B-Tree.** Uma página de grau mínimo `t` comporta até `2t−1` chaves. Em um split, a mediana sobe, as páginas resultantes recebem `t−1` chaves cada, e seus filhos são redistribuídos. O split da raiz aumenta a altura. O programa exibe a altura e o total de splits.
- **LSM-Tree.** A memtable ordenada faz flush ao acumular o limite de chaves distintas. Cada flush cria uma SSTable imutável em memória. A leitura consulta primeiro a memtable e depois as SSTables da mais recente para a mais antiga. Um tombstone encerra a busca com a chave ausente. A compactação mescla a memtable e todas as SSTables, mantém a versão mais recente e descarta tombstones e versões antigas. Os testes verificam a precedência e a ausência de ressurreição de chaves.
- **Bloom filter.** Cada SSTable inclui as chaves dos tombstones no filtro. Uma resposta negativa poupa uma sondagem. Uma resposta positiva exige busca na tabela e pode ser um falso positivo. O console faz as mesmas leituras de chaves ausentes com e sem o filtro.

As métricas contam operações e registros do modelo:

- **Amplificação de leitura.** Média de SSTables sondadas por consulta no lote de chaves ausentes. Consultas satisfeitas pela memtable fazem zero sondagens de SSTables.
- **Amplificação de escrita.** Registros gravados em flushes e compactações divididos pelo total de mutações lógicas, incluindo exclusões. O quociente pode ficar abaixo de 1 quando a memtable combina múltiplas operações sobre a mesma chave.
- **Amplificação de espaço.** Registros mantidos na memtable e SSTables, incluindo tombstones e versões antigas, divididos pelas chaves vivas. Razões com denominador zero ficam indefinidas.

A B-Tree usa capacidade por número de chaves. As SSTables são vetores ordenados em memória. Os contadores não estimam bytes, I/O, tempo, persistência ou recuperação de uma engine real.

## Medições no PostgreSQL 18

Na pasta `labs/storage-engines/postgresql`, com Docker Compose e PowerShell:

```powershell
docker compose up -d --wait
./check.ps1
docker compose down
```

O Compose cria o banco `storage_engines` em um volume próprio, com acesso por `docker compose exec` e sem publicar portas. A verificação recria somente as tabelas didáticas no schema `storage_lab`. Execute a sequência sem outros experimentos concorrentes nesse banco. As extensões são incluídas na imagem PostgreSQL e os scripts usam o superusuário local de laboratório para inspecionar as páginas e o WAL.

Para executar um experimento isoladamente, substitua o nome do arquivo no comando:

```powershell
docker compose exec -T db psql -X -U lab -d storage_engines -f /lab/sql/01_btree.sql
```

1. **B-Tree e splits** — [01_btree.sql](postgresql/sql/01_btree.sql). Insere 30 mil chaves após criar o índice, compara o nível da raiz, inventaria páginas e lê os registros de split no intervalo WAL da carga. O plano de busca mostra os buffers observados naquela execução.
2. **VACUUM e bloat** — [02_vacuum.sql](postgresql/sql/02_vacuum.sql). Coleta tamanho do heap, tuplas mortas e espaço livre após apagar 80% das linhas. Com `TRUNCATE FALSE`, o VACUUM torna o espaço reutilizável e conserva o tamanho do arquivo. O VACUUM FULL reescreve a tabela e reduz o arquivo neste cenário.
3. **WAL e checkpoints** — [03_wal.sql](postgresql/sql/03_wal.sql). Compara atualizações da mesma página antes e logo após um checkpoint explícito. Com `full_page_writes` ativo, a primeira alteração após o checkpoint pode gravar uma imagem da página completa, que protege contra gravações parciais durante recuperação. Compare os registros/bytes/FPI do statement e a diferença entre LSNs, que inclui WAL do cluster. O exercício observa geração de WAL e metadados do checkpoint. Um teste de recuperação exigiria reiniciar o servidor após uma falha.
4. **MVCC e snapshot aberto** — [04_mvcc_check.sql](postgresql/sql/04_mvcc_check.sql). A sessão leitora fixa um snapshot em REPEATABLE READ; uma segunda conexão confirma o saldo novo e chama VACUUM. A leitora ainda vê 900 e duas versões físicas. Após o COMMIT da leitora, uma nova consulta vê 1.000 e outro VACUUM deixa uma versão física.

Para acompanhar o MVCC manualmente, rode `04_mvcc_setup.sql` uma vez e abra o `psql` em dois terminais com `docker compose exec db psql -X -U lab -d storage_engines`. No terminal A, execute `BEGIN ISOLATION LEVEL REPEATABLE READ;` e `SELECT balance FROM storage_lab.mvcc_demo WHERE id = 1;`. No terminal B, rode `\i /lab/sql/04_mvcc_writer.sql`. No A, repita a consulta, confirme a transação e execute a consulta outra vez. No B, repita `VACUUM (VERBOSE, TRUNCATE FALSE) storage_lab.mvcc_demo;` e compare a remoção de versões com a primeira execução.

A verificação termina com código diferente de zero se uma checagem falhar. Tempos, buffers e posições WAL variam por execução. Para comparar sessões, registre a versão do servidor, o plano, as contagens e os bytes observados.

## Resultados observados

Em 25 de novembro de 2026, os testes do console passaram com o SDK .NET 8.0.426. No cenário do console, a compactação reduziu 13 SSTables a uma e a amplificação de espaço de 4,22× para 1,00×. A amplificação acumulada de escrita passou de 1,00× para 1,24×.

As quatro verificações SQL passaram no PostgreSQL 18.7:

- A carga de 30 mil chaves produziu 81 splits registrados no WAL e 82 páginas folha.
- Após excluir 16 mil linhas, o VACUUM limpou as tuplas mortas e o heap permaneceu em 6.070.272 bytes. O VACUUM FULL reduziu o heap para 1.220.608 bytes.
- O intervalo de WAL da atualização logo após o checkpoint incluiu 1.668 bytes de imagem de página. O intervalo da atualização anterior teve zero bytes de imagem de página.
- O leitor em REPEATABLE READ continuou vendo 900 após a confirmação de 1.000 pelo escritor. Depois do COMMIT do leitor, a próxima consulta viu 1.000 e o VACUUM removeu a versão anterior.

Use os valores para comparar a ordem de grandeza em uma nova execução. Os testes verificam os efeitos de cada experimento e deixam os totais de WAL e de páginas variarem.


## Referências

- [PostgreSQL 18 — pageinspect](https://www.postgresql.org/docs/18/pageinspect.html)
- [PostgreSQL 18 — pgstattuple](https://www.postgresql.org/docs/18/pgstattuple.html)
- [PostgreSQL 18 — pg_walinspect](https://www.postgresql.org/docs/18/pgwalinspect.html)
- [PostgreSQL 18 — manutenção com VACUUM](https://www.postgresql.org/docs/18/routine-vacuuming.html)
