using System.Diagnostics;
using Npgsql;

sealed class ShardCluster : IDisposable
{
    private readonly NpgsqlConnection[] nodes = Enumerable.Range(0, 5)
        .Select(i => new NpgsqlConnection($"Host=127.0.0.1;Port={5436+i};Database=sharding_lab;Username=lab;Password=lab_dev_only")).ToArray();

    public void Run(int count, bool ring)
    {
        foreach (var node in nodes) node.Open();
        IRouter before = ring ? new RingRouter(4, 128) : new ModuloRouter(4);
        IRouter after = ring ? new RingRouter(5, 128) : new ModuloRouter(5);
        foreach (var node in nodes)
        {
            using var cmd = new NpgsqlCommand("""
                DROP TABLE IF EXISTS lab_items;
                CREATE TABLE lab_items (
                    id integer PRIMARY KEY,
                    category integer NOT NULL,
                    payload text NOT NULL
                );
                """, node);
            cmd.ExecuteNonQuery();
        }
        var keys = Enumerable.Range(1, count).ToArray();
        foreach (var group in keys.GroupBy(id => before.Locate(Simulation.Key(id))))
            Insert(group.Key, group.ToArray());
        Verify(before, count, "before");
        CheckScatterGather(count, 7);

        var moves = keys.Select(id => (Id: id, From: before.Locate(Simulation.Key(id)), To: after.Locate(Simulation.Key(id))))
            .Where(x => x.From != x.To).GroupBy(x => (x.From, x.To)).ToArray();
        int moved = moves.Sum(g => g.Count());
        var timer = Stopwatch.StartNew();
        // Copy and validate every destination before deleting any original record.
        // This is an offline exercise: no reads/writes from external clients during migration.
        foreach (var group in moves)
        {
            var ids = group.Select(x => x.Id).ToArray();
            Copy(group.Key.From, group.Key.To, ids);
        }
        foreach (var group in moves)
            foreach (int id in group.Select(x => x.Id))
                Simulation.Require(Read(group.Key.From, id) == Read(group.Key.To, id),
                    $"Copied record differs: {id}");
        foreach (var group in moves)
        {
            var ids = group.Select(x => x.Id).ToArray();
            using var cmd = new NpgsqlCommand("DELETE FROM lab_items WHERE id = ANY(@ids)", nodes[group.Key.From]);
            cmd.Parameters.AddWithValue("ids", ids);
            Simulation.Require(cmd.ExecuteNonQuery() == ids.Length, "Source delete count mismatch.");
        }
        timer.Stop();
        Verify(after, count, "after");
        CheckScatterGather(count, 7);
        Console.WriteLine($"Physical rebalance ({(ring ? "ring" : "modulo")}): moved={moved}/{count} ({100.0*moved/count:F2}%); copy/verify/delete={timer.Elapsed.TotalMilliseconds:F1}ms.");
        Console.WriteLine("Real shard integrity checks passed.");
    }

    private void Insert(int node, int[] ids)
    {
        using var cmd = new NpgsqlCommand("""
            INSERT INTO lab_items(id, category, payload)
            SELECT id, id % 10, 'item-' || id FROM unnest(@ids) AS t(id)
            """, nodes[node]);
        cmd.Parameters.AddWithValue("ids", ids);
        Simulation.Require(cmd.ExecuteNonQuery() == ids.Length, "Seed insert count mismatch.");
    }

    private void Copy(int source, int target, int[] ids)
    {
        // The source is the authoritative record; do not regenerate its payload from the key.
        var copied = new List<(int Id, int Category, string Payload)>();
        using (var select = new NpgsqlCommand("SELECT id, category, payload FROM lab_items WHERE id = ANY(@ids)", nodes[source]))
        {
            select.Parameters.AddWithValue("ids", ids);
            using var reader = select.ExecuteReader();
            while (reader.Read()) copied.Add((reader.GetInt32(0), reader.GetInt32(1), reader.GetString(2)));
        }
        Simulation.Require(copied.Count == ids.Length, "Missing source record.");
        using var insert = new NpgsqlCommand("""
            INSERT INTO lab_items(id, category, payload)
            SELECT id, category, payload FROM unnest(@ids, @categories, @payloads) AS t(id, category, payload)
            """, nodes[target]);
        insert.Parameters.AddWithValue("ids", copied.Select(r => r.Id).ToArray());
        insert.Parameters.AddWithValue("categories", copied.Select(r => r.Category).ToArray());
        insert.Parameters.AddWithValue("payloads", copied.Select(r => r.Payload).ToArray());
        Simulation.Require(insert.ExecuteNonQuery() == copied.Count, "Destination copy count mismatch.");
    }

    private (int Category, string Payload) Read(int node, int id)
    {
        using var cmd = new NpgsqlCommand("SELECT category, payload FROM lab_items WHERE id = @id", nodes[node]);
        cmd.Parameters.AddWithValue("id", id);
        using var reader = cmd.ExecuteReader();
        if (!reader.Read()) throw new InvalidOperationException($"Missing key {id} in shard {node}");
        return (reader.GetInt32(0), reader.GetString(1));
    }

    private void Verify(IRouter router, int count, string stage)
    {
        var seen = new HashSet<int>();
        var distribution = new int[5];
        for (int node = 0; node < nodes.Length; node++)
        {
            using var cmd = new NpgsqlCommand("SELECT id, category, payload FROM lab_items", nodes[node]);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                int id = reader.GetInt32(0);
                Simulation.Require(id >= 1 && id <= count && seen.Add(id), $"Unexpected or duplicated id {id}");
                Simulation.Require(router.Locate(Simulation.Key(id)) == node, $"Key {id} is on wrong shard");
                Simulation.Require(reader.GetInt32(1) == id % 10 && reader.GetString(2) == "item-" + Simulation.Key(id),
                    $"Payload mismatch for {id}");
                distribution[node]++;
            }
        }
        Simulation.Require(seen.Count == count, "Global record count mismatch.");
        Console.WriteLine($"{stage}: {seen.Count} unique records; distribution={string.Join(", ", distribution)}");
    }

    private void CheckScatterGather(int count, int category)
    {
        var timer = Stopwatch.StartNew();
        long total = 0;
        foreach (var node in nodes)
        {
            using var cmd = new NpgsqlCommand("SELECT COUNT(*) FROM lab_items WHERE category = @category", node);
            cmd.Parameters.AddWithValue("category", category);
            total += (long)cmd.ExecuteScalar()!;
        }
        timer.Stop();
        Simulation.Require(total == Enumerable.Range(1, count).Count(id => id % 10 == category),
            "Scatter-gather result mismatch.");
        Console.WriteLine($"Scatter-gather category={category}; rows={total}; 5 serial queries={timer.Elapsed.TotalMilliseconds:F1}ms");
    }

    public void Dispose()
    {
        foreach (var node in nodes) node.Dispose();
    }
}
