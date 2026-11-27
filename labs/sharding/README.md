# Lab 06 — Sharding e Consistent Hashing

## Objetivo

Comparar roteamento por módulo com um anel de consistent hashing, observar o impacto de virtual nodes e hot keys e transferir registros entre instâncias PostgreSQL independentes quando o cluster cresce de quatro para cinco shards. Este laboratório não depende do Lab 05.

## Executar

Requisitos: SDK .NET 10, PowerShell 7 e Docker Desktop com Compose (somente para a etapa real).

Na pasta `labs/sharding`:

```powershell
./check.ps1
./check.ps1 -Real -Keys 100000 -RealKeys 2000
docker compose down
```

O primeiro comando simula 100.000 chaves. O segundo repete a simulação, inicia cinco servidores PostgreSQL 18 com bancos e volumes próprios e roda os dois algoritmos em dados persistidos. Portas locais: 5436 a 5440, vinculadas a 127.0.0.1. As credenciais são exclusivamente didáticas. O volume é preservado após `down`; `down -v` apaga os volumes deste laboratório.

**Atenção:** os modos reais recriam `lab_items` em todas as cinco instâncias dedicadas. Não use dados reais e não rode dois testes em paralelo. O rebalanceamento ocorre offline, sem clientes externos alterando os registros.

Também é possível executar isoladamente:

```powershell
dotnet run --project Sharding --configuration Release -- simulate 100000
docker compose up -d --wait
dotnet run --project Sharding --configuration Release -- real-modulo 2000
dotnet run --project Sharding --configuration Release -- real-ring 2000
```

## Experimentos

| ID | Experimento | Critério verificável |
|---|---|---|
| SH-01 | Hash por módulo, 4 → 5 | Cada chave pertence a um shard; contar remapeamentos e movimentos entre nós antigos |
| SH-02 | Anel com 1 virtual node por nó | Chaves movidas vão exclusivamente para o novo nó; medir desequilíbrio |
| SH-03 | Anel com 128 virtual nodes por nó | Mesma propriedade; observar distribuição max/média |
| SH-04 | Hot key | 50% das requisições miram uma única chave; contabilizar tráfego por shard |
| SH-05 | Sharding físico | Cada registro é persistido no shard correto; unicidade global e payload verificados |
| SH-06 | Rebalanceamento offline | Copiar dados reais, conferir destino antes de remover origem, validar todos os registros após a migração |
| SH-07 | Scatter-gather | Consultar categoria nos cinco servidores, agregar contagens e confrontar com resultado esperado |

O hash é SHA-256 em UTF-8, truncado aos primeiros 64 bits em big-endian. O roteamento é determinístico e não depende de GetHashCode ou do processo. Cada vnode é posicionado a partir do identificador do nó e do índice do vnode. O anel escolhe o primeiro token maior ou igual ao hash da chave e retorna ao início quando necessário.

## Matemática e verificação independente

Sob hash uniforme, módulo 4 → 5 move em média 80% das chaves. Em um anel ideal e equilibrado, acrescentar um nó de capacidade equivalente move aproximadamente 20%. O valor efetivo depende da posição dos tokens e do conjunto de chaves.

Os seguintes resultados foram reproduzidos com um script Python independente usando a mesma função de hash, as chaves 1–100.000 e a mesma definição do anel. Não são resultados da execução do console C# nem de uma migração PostgreSQL.

| Estratégia | Chaves movidas | Entre nós antigos | Distribuição final (0–4) |
|---|---:|---:|---|
| Módulo | 79.651 (79,651%) | 59.820 | 20.035 / 20.177 / 19.800 / 20.157 / 19.831 |
| Anel, 1 vnode | 1.284 (1,284%) | 0 | 15.636 / 14.544 / 33.016 / 35.520 / 1.284 |
| Anel, 128 vnodes | 17.535 (17,535%) | 0 | 21.103 / 21.282 / 20.638 / 19.442 / 17.535 |

Pouca movimentação não significa necessariamente bom balanceamento: no anel de um vnode, o novo nó recebe apenas 1,284% dos registros. Virtual nodes ajudam a distribuir intervalos, mas não dividem uma única hot key nem garantem igualdade de carga.

## Garantias e limitações

- A simulação mede chaves e distribuição, não bytes, throughput ou latência de rede.
- O teste real mede o intervalo de cópia, verificação e remoção, não a duração total de um rebalanceamento de produção.
- A transferência mantém os registros de origem até todos os destinos serem conferidos. Não existe transação atômica global. Uma falha pode deixar duplicatas temporárias ou migração incompleta; o processo não é retomável nem seguro para escritas concorrentes. Reexecutar o exercício recria o dataset.
- Cada instância aplica sua PK local. A unicidade global é uma propriedade validada pelo cliente neste cenário, não uma constraint nativa compartilhada.
- Scatter-gather é serial, não paralelizado; a métrica inclui cinco roundtrips e execução. Uma consulta por chave pode ser roteada a um único shard; consultas sem a shard key podem exigir vários shards.
- Não há réplicas, failover, consenso, roteamento dinâmico em produção ou tolerância a partições. Replicação e CAP são próximos laboratórios.

## Checklist

- [ ] Compilar com SDK .NET 10.
- [ ] Executar a simulação e conferir os resultados de referência.
- [ ] Iniciar os cinco contêineres.
- [ ] Rodar real-modulo e verificar a integridade antes e após migração.
- [ ] Rodar real-ring e verificar a integridade antes e após migração.
- [ ] Registrar distribuição, registros movidos, tempos e ambiente.
- [ ] Analisar o hot key e o custo de scatter-gather.
- [ ] Documentar os limites do método e possíveis estratégias de migração online.

**Estado inicial:** lógica de hash e distribuição verificada independentemente em Python. A compilação C# e a integração com cinco instâncias PostgreSQL ainda precisam ser executadas; nenhum resultado de desempenho real foi inventado.
