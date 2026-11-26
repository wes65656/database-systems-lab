using StorageEngines;

if (args.SequenceEqual(new[] { "--test" }))
{
    Checks.Run();
    return 0;
}
if (args.Length != 0)
{
    Console.Error.WriteLine("Uso: StorageEngines [--test]");
    return 2;
}

Console.WriteLine("SIMULAÇÃO DIDÁTICA | B-Tree e LSM-Tree em memória");
var tree = new BTree(3);
foreach (int key in Enumerable.Range(1, 100))
    tree.Insert(key);
Console.WriteLine($"B-Tree: {tree.Scan().Count()} chaves, altura {tree.Height}, splits {tree.Splits}");

var lsm = new LsmTree(8);
for (int round = 0; round < 4; round++)
    foreach (int key in Enumerable.Range(1, 24))
        lsm.Put(key, $"versão {round}");
lsm.Delete(1);
lsm.Flush();
Show("antes da compactação");
lsm.Compact();
Show("depois da compactação");
return 0;

void Show(string stage)
{
    int[] absent = Enumerable.Range(100, 100).ToArray();
    var reads = absent.Select(key => lsm.Read(key)).ToArray();
    double noBloom = absent.Average(key => lsm.Read(key, useBloom: false).Probes);
    Console.WriteLine($"LSM {stage}: {lsm.TableCount} SSTables, {lsm.StoredRecords} registros, {lsm.LiveKeys} chaves vivas");
    Console.WriteLine($"  sondagens por leitura ausente: {noBloom:F2} sem Bloom, {reads.Average(read => read.Probes):F2} com Bloom");
    Console.WriteLine($"  descartes Bloom: {reads.Sum(read => read.Skips)}, falsos positivos: {reads.Sum(read => read.FalsePositives)}");
    Console.WriteLine($"  amplificação de escrita: {lsm.WriteAmplification:F2}x, espaço: {lsm.SpaceAmplification:F2}x");
}
