# Lab 05 — SQL versus NoSQL

## Objetivo

Comparar PostgreSQL 18 e MongoDB 8 em um workload de chave primária equivalente, com persistência local e verificação de integridade. Não existe um vencedor universal: este laboratório observa operações, configurações e custos específicos.

## Preparação

Docker Desktop / Compose, PowerShell 7 e SDK .NET 10. Na pasta deste laboratório:

```powershell
./check.ps1
```

O script inicia os serviços, aguarda os health checks e executa o console em Release. As portas locais são 5435 (PostgreSQL) e 27018 (MongoDB). As credenciais são de laboratório, nunca de produção. Os bancos e volumes são independentes dos outros labs.

**Atenção:** cada rodada recria a tabela ou coleção `items` dentro do banco dedicado `sql_nosql_lab`. Não guarde dados importantes nesse ambiente. Execute apenas uma instância do benchmark por vez.

## Experimentos

| Cenário | Leitura por chave | Atualização por chave |
|---|---:|---:|
| Read-heavy | 90% | 10% |
| Mixed | 50% | 50% |
| Write-heavy | 10% | 90% |
| Write-only | 0% | 100% |

Para cada cenário e motor:

1. Recriar os dados: por padrão 15.000 registros, categoria determinística, payload de 128 caracteres e contador zero.
2. Medir a inserção em lotes de 500, separadamente do workload.
3. Conferir todas as chaves, categorias, payloads e contadores.
4. Aquecer leituras de 100 chaves e executar a mesma sequência determinística de 3.000 operações nos dois bancos.
5. Validar o resultado de cada leitura e atualização, e conferir novamente todos os registros no fim.
6. Registrar throughput e percentis de latência por tipo de operação.

PostgreSQL usa PK B-tree, SELECT e UPDATE condicional por chave (incremento atômico de uma linha). MongoDB usa o índice de `_id`, find e `$inc`. As duas escritas incrementam um contador; não são transações multi-entidade.

### Batching e escalas

```powershell
./check.ps1 -Rows 1000 -Operations 400 -Batch 100
./check.ps1 -Rows 15000 -Operations 3000 -Batch 1
./check.ps1 -Rows 15000 -Operations 3000 -Batch 500
./check.ps1 -Rows 100000 -Operations 10000 -Batch 500
```

O primeiro é um teste rápido de funcionamento; os demais exploram tamanho e batching. As cargas podem demorar, em especial a inserção unitária, por reconhecer cada escrita.

### Capturar resultados

```powershell
New-Item -ItemType Directory -Force results | Out-Null
./check.ps1 -Rows 15000 -Operations 3000 -Batch 500 2>&1 | Tee-Object results/batch500.txt
docker compose down
```

Não use o arquivo bruto como evidência de sucesso se o comando terminar com erro. O programa retorna código 1 em erro ou divergência. `docker compose down` mantém os volumes; `down -v` os apaga.

## Metodologia e garantias

- PostgreSQL usa autocommit por comando, `synchronous_commit=on` e verifica `fsync=on`. MongoDB standalone usa `w=1`, journaling e sem retryable writes. São confirmações locais; não provam a mesma resistência a todos os tipos de falhas, nem garantias de replicação.
- Inserções PostgreSQL usam uma instrução com vetor de IDs e payload parametrizado, e MongoDB usa InsertMany ordenado. Os formatos de transporte e a atomicidade do lote são diferentes. Compare as estratégias concretas, não atribua toda diferença ao tipo de banco.
- Workloads usam um cliente por vez, chaves uniformemente distribuídas e sequência com seed 42. Não representam capacidade máxima, concorrência, hotspot, joins, cache frio ou produção.
- O cronômetro de operações mede latência percebida pelo cliente, incluindo driver e rede local. Throughput inclui o loop; p95/p99 usam nearest-rank. A verificação e o aquecimento não entram no intervalo medido.
- Os serviços coexistem no Docker Desktop e compartilham recursos. Repita rodadas, registre CPU/RAM, versão, duração, ordem e cache. Não tire conclusões de uma única rodada.

## Validação

- [ ] Docker Compose inicia os dois serviços.
- [ ] Console compila e executa com o SDK .NET 10.
- [ ] Cada cenário usa exatamente a mesma sequência de operações nos dois motores.
- [ ] Todos os registros e contadores correspondem ao modelo esperado.
- [ ] O console encerra com código zero e imprime All workload integrity checks passed.
- [ ] Repetir o teste com batch 1 e 500.
- [ ] Registrar as medições reais e interpretar os trade-offs.

**Estado inicial:** código preparado e versionado. Compilação e execução com os motores reais ainda pendentes de validação; nenhuma medição foi inventada.

## Evolução

Comparação de consultas por categoria e índices secundários; modelagem normalizada versus documentos com itens embutidos; concorrência, contenção e distribuição enviesada; armazenamento e recuperação; bancos wide-column/colunares em labs próprios. Este lab não testa CAP nem configura replicação.

## Questões de engenharia

- O custo de gravar um lote é equivalente ao custo de N escritas confirmadas individualmente?
- Um resultado melhor de p95 implica necessariamente throughput superior?
- Que requisitos mudariam a escolha entre documento e relacional?
- O que muda ao introduzir transações multi-documento, joins, réplicas ou partições de rede?
