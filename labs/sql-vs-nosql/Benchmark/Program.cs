using System.Diagnostics;
using System.Globalization;
using MongoDB.Bson;
using MongoDB.Driver;
using Npgsql;

CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;

try
{
    int rows = Parse(0, 15_000, 100, 1_000_000);
    int operations = Parse(1, 3_000, 100, 1_000_000);
    int batch = Parse(2, 500, 1, 5_000);
    if (args.Length > 3) throw new ArgumentException("Usage: Benchmark [rows] [operations] [batch]");
    Console.WriteLine($"rows={rows}; operations={operations}; batch={batch}; seed=42");

    using var pg = new PostgresStore();
    var mongo = new MongoStore();
    var stores = new IStore[] { pg, mongo };
    foreach (var (name, readPercent) in new[] { ("read-heavy", 90), ("mixed", 50), ("write-heavy", 10), ("write-only", 0) })
    {
        var schedule = Workload.Create(rows, operations, readPercent);
        // Alternate execution order to avoid always giving the same engine first-run conditions.
        if (readPercent != 90) Array.Reverse(stores);
        foreach (var store in stores)
        {
            store.Reset();
            var seedStart = Stopwatch.GetTimestamp();
            for (int i = 1; i <= rows; i += batch)
                store.Insert(i, Math.Min(batch, rows - i + 1));
            double seedSeconds = Stopwatch.GetElapsedTime(seedStart).TotalSeconds;
            var expected = new int[rows + 1];
            store.Verify(expected);

            // Warm up the driver and point reads without modifying the dataset.
            for (int i = 1; i <= Math.Min(rows, 100); i++)
                if (store.Read(i) != 0) throw new InvalidOperationException("Warmup mismatch.");

            var readMs = new List<double>();
            var writeMs = new List<double>();
            var runStart = Stopwatch.GetTimestamp();
            foreach (var op in schedule)
            {
                long start = Stopwatch.GetTimestamp();
                if (op.Read)
                {
                    int value = store.Read(op.Id);
                    readMs.Add(Stopwatch.GetElapsedTime(start).TotalMilliseconds);
                    if (value != expected[op.Id]) throw new InvalidOperationException($"Read mismatch: {store.Name}, id={op.Id}");
                }
                else
                {
                    store.Increment(op.Id);
                    writeMs.Add(Stopwatch.GetElapsedTime(start).TotalMilliseconds);
                    expected[op.Id]++;
                }
            }
            double seconds = Stopwatch.GetElapsedTime(runStart).TotalSeconds;
            store.Verify(expected);
            Console.WriteLine($"\n{name} | {store.Name} | verified={rows} | increments={writeMs.Count}");
            Console.WriteLine($"seed: {seedSeconds:F3}s, {rows / seedSeconds:F1} rows/s");
            Console.WriteLine($"workload: {seconds:F3}s, {operations / seconds:F1} ops/s");
            Report("read", readMs);
            Report("write", writeMs);
        }
    }
    Console.WriteLine("\nAll workload integrity checks passed.");
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex);
    return 1;
}

int Parse(int index, int fallback, int min, int max)
{
    if (args.Length <= index) return fallback;
    if (!int.TryParse(args[index], out int value) || value < min || value > max)
        throw new ArgumentException($"Argument {index + 1} must be between {min} and {max}.");
    return value;
}

static void Report(string label, List<double> values)
{
    if (values.Count == 0) { Console.WriteLine($"{label}: n=0"); return; }
    values.Sort();
    double P(double p) => values[(int)Math.Ceiling(p * values.Count) - 1];
    Console.WriteLine($"{label}: n={values.Count}, p50={P(.50):F3}ms, p95={P(.95):F3}ms, p99={P(.99):F3}ms");
}

readonly record struct Operation(int Id, bool Read);
static class Workload
{
    public static Operation[] Create(int rows, int count, int readPercent)
    {
        var random = new Random(42);
        int reads = (int)((long)count * readPercent / 100);
        var result = Enumerable.Range(0, count).Select(i => new Operation(random.Next(1, rows + 1), i < reads)).ToArray();
        for (int i = result.Length - 1; i > 0; i--)
        {
            int j = random.Next(i + 1);
            (result[i], result[j]) = (result[j], result[i]);
        }
        return result;
    }
}

interface IStore
{
    string Name { get; }
    void Reset();
    void Insert(int firstId, int count);
    int Read(int id);
    void Increment(int id);
    void Verify(int[] expected);
}

sealed class PostgresStore : IStore, IDisposable
{
    private readonly NpgsqlConnection connection = new("Host=127.0.0.1;Port=5435;Database=sql_nosql_lab;Username=lab;Password=lab_dev_only");
    public string Name => "PostgreSQL";
    public PostgresStore()
    {
        connection.Open();
        using var cmd = new NpgsqlCommand("SET synchronous_commit = on", connection);
        // Read the setting separately so multi-statement result semantics cannot mask it.
        cmd.ExecuteNonQuery();
        cmd.CommandText = "SHOW fsync";
        if ((string?)cmd.ExecuteScalar() != "on") throw new InvalidOperationException("Expected fsync=on.");
    }
    public void Reset()
    {
        using var cmd = new NpgsqlCommand("""
            DROP TABLE IF EXISTS items;
            CREATE TABLE items (id integer PRIMARY KEY, category integer NOT NULL, payload text NOT NULL, counter integer NOT NULL DEFAULT 0);
            """, connection);
        cmd.ExecuteNonQuery();
    }
    public void Insert(int firstId, int count)
    {
        var ids = Enumerable.Range(firstId, count).ToArray();
        using var cmd = new NpgsqlCommand("""
            INSERT INTO items(id, category, payload)
            SELECT id, id % 100, @payload FROM unnest(@ids) AS t(id)
            """, connection);
        cmd.Parameters.AddWithValue("ids", ids);
        cmd.Parameters.AddWithValue("payload", new string('x', 128));
        if (cmd.ExecuteNonQuery() != count) throw new InvalidOperationException("PostgreSQL insert count mismatch.");
    }
    public int Read(int id)
    {
        using var cmd = new NpgsqlCommand("SELECT counter FROM items WHERE id = @id", connection);
        cmd.Parameters.AddWithValue("id", id);
        return cmd.ExecuteScalar() is int counter ? counter : throw new InvalidOperationException("Missing PostgreSQL row.");
    }
    public void Increment(int id)
    {
        using var cmd = new NpgsqlCommand("UPDATE items SET counter = counter + 1 WHERE id = @id", connection);
        cmd.Parameters.AddWithValue("id", id);
        if (cmd.ExecuteNonQuery() != 1) throw new InvalidOperationException("PostgreSQL update count mismatch.");
    }
    public void Verify(int[] expected)
    {
        using var cmd = new NpgsqlCommand("SELECT id, counter, category, payload FROM items ORDER BY id", connection);
        using var reader = cmd.ExecuteReader();
        int next = 1;
        while (reader.Read())
        {
            if (next >= expected.Length || reader.GetInt32(0) != next || reader.GetInt32(1) != expected[next] ||
                reader.GetInt32(2) != next % 100 || reader.GetString(3) != new string('x', 128))
                throw new InvalidOperationException($"PostgreSQL integrity mismatch at id={next}.");
            next++;
        }
        if (next != expected.Length) throw new InvalidOperationException("PostgreSQL row count mismatch.");
    }
    public void Dispose() => connection.Dispose();
}

sealed class MongoStore : IStore
{
    private readonly IMongoDatabase db = new MongoClient("mongodb://lab:lab_dev_only@127.0.0.1:27018/?authSource=admin&w=1&journal=true&retryWrites=false").GetDatabase("sql_nosql_lab");
    private IMongoCollection<BsonDocument> Items => db.GetCollection<BsonDocument>("items");
    public string Name => "MongoDB";
    public void Reset()
    {
        db.DropCollection("items");
        db.CreateCollection("items");
    }
    public void Insert(int firstId, int count)
    {
        Items.InsertMany(Enumerable.Range(firstId, count).Select(id => new BsonDocument
        {
            { "_id", id }, { "category", id % 100 }, { "payload", new string('x', 128) }, { "counter", 0 }
        }), new InsertManyOptions { IsOrdered = true });
    }
    public int Read(int id)
    {
        var result = Items.Find(Builders<BsonDocument>.Filter.Eq("_id", id))
            .Project(Builders<BsonDocument>.Projection.Include("counter").Exclude("_id")).FirstOrDefault();
        return result is null ? throw new InvalidOperationException("Missing MongoDB document.") : result["counter"].AsInt32;
    }
    public void Increment(int id)
    {
        var result = Items.UpdateOne(Builders<BsonDocument>.Filter.Eq("_id", id), Builders<BsonDocument>.Update.Inc("counter", 1));
        if (!result.IsAcknowledged || result.MatchedCount != 1 || result.ModifiedCount != 1)
            throw new InvalidOperationException("MongoDB update count mismatch.");
    }
    public void Verify(int[] expected)
    {
        using var cursor = Items.Find(FilterDefinition<BsonDocument>.Empty).Sort(Builders<BsonDocument>.Sort.Ascending("_id")).ToCursor();
        int next = 1;
        while (cursor.MoveNext())
            foreach (var item in cursor.Current)
            {
                if (next >= expected.Length || item["_id"].AsInt32 != next || item["counter"].AsInt32 != expected[next] ||
                    item["category"].AsInt32 != next % 100 || item["payload"].AsString != new string('x', 128))
                    throw new InvalidOperationException($"MongoDB integrity mismatch at id={next}.");
                next++;
            }
        if (next != expected.Length) throw new InvalidOperationException("MongoDB document count mismatch.");
    }
}
