namespace StorageEngines;

internal static class Checks
{
    public static void Run()
    {
        var random = new Random(31);
        int[] keys = Enumerable.Range(-500, 1000).OrderBy(_ => random.Next()).ToArray();
        foreach (int degree in new[] { 2, 3, 16 })
        {
            var tree = new BTree(degree);
            foreach (int key in keys)
                Require(tree.Insert(key), "inserção na B-Tree");
            Require(tree.Height > 1 && tree.Splits > 0, "split da raiz e de páginas filhas");
            Require(keys.All(tree.Contains) && !tree.Contains(500), "busca B-Tree");
            Require(!tree.Insert(keys[0]) && tree.Scan().SequenceEqual(keys.Order()), "ordem e unicidade");
        }

        var saturated = new BloomFilter(1);
        saturated.Add(-1);
        Require(saturated.MightContain(-1) && saturated.MightContain(2), "Bloom admite falso positivo");

        var lsm = new LsmTree(2, 1);
        lsm.Put(1, "original");
        lsm.Put(2, "preservado");
        lsm.Put(1, "atualizado");
        Require(lsm.Read(1).Value == "atualizado", "memtable tem precedência");
        lsm.Flush();
        Require(lsm.Read(1).Value == "atualizado", "SSTable mais recente vence");
        lsm.Delete(1);
        lsm.Flush();
        Require(lsm.Read(1).Value is null, "tombstone impede leitura de versão antiga");
        Require(lsm.Read(99) == (null, 3, 0, 3), "sondagens e falsos positivos");
        Require(lsm.WrittenRecords == 4 && lsm.SpaceAmplification == 4, "contadores antes da compactação");
        lsm.Compact();
        Require(lsm.TableCount == 1 && lsm.Read(1).Value is null && lsm.Read(2).Value == "preservado", "compactação");
        Require(lsm.WrittenRecords == 5 && lsm.WriteAmplification == 1.25 && lsm.SpaceAmplification == 1, "contadores após compactação");

        var withBloom = new LsmTree(2);
        var expected = new Dictionary<int, string>();
        for (int iteration = 0; iteration < 400; iteration++)
        {
            int key = random.Next(-20, 20);
            if (iteration % 3 == 0)
            {
                expected.Remove(key);
                withBloom.Delete(key);
            }
            else
            {
                expected[key] = iteration.ToString();
                withBloom.Put(key, expected[key]);
            }
            if (iteration % 17 == 0)
                withBloom.Compact();
            for (int candidate = -21; candidate <= 21; candidate++)
            {
                var filtered = withBloom.Read(candidate);
                var unfiltered = withBloom.Read(candidate, useBloom: false);
                Require(filtered.Value == expected.GetValueOrDefault(candidate)
                    && unfiltered.Value == filtered.Value && filtered.Probes <= unfiltered.Probes, "modelo de referência e filtro Bloom");
            }
        }
        withBloom.Flush();
        Require(withBloom.Read(1000).Skips > 0, "Bloom evita sondagens");
        Console.WriteLine("Testes da simulação passaram.");
    }

    private static void Require(bool condition, string description)
    {
        if (!condition)
            throw new InvalidOperationException($"Falha: {description}");
    }
}
