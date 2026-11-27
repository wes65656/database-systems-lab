using System.Buffers.Binary;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

interface IRouter
{
    int Locate(string key);
}
static class StableHash
{
    public static ulong Of(string value) =>
        BinaryPrimitives.ReadUInt64BigEndian(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
sealed class ModuloRouter(int count) : IRouter
{
    private readonly int nodes = count > 0 ? count : throw new ArgumentOutOfRangeException(nameof(count));
    public int Locate(string key) => (int)(StableHash.Of(key) % (ulong)nodes);
}
sealed class RingRouter : IRouter
{
    private readonly (ulong Hash, int Node, int Replica)[] ring;
    public RingRouter(int nodes, int virtualNodes)
    {
        if (nodes <= 0 || virtualNodes <= 0) throw new ArgumentOutOfRangeException();
        ring = Enumerable.Range(0, nodes)
            .SelectMany(n => Enumerable.Range(0, virtualNodes).Select(v =>
                (Hash: StableHash.Of(FormattableString.Invariant($"node:{n}:vnode:{v}")), Node: n, Replica: v)))
            .OrderBy(x => x.Hash).ThenBy(x => x.Node).ThenBy(x => x.Replica).ToArray();
    }
    public int Locate(string key)
    {
        ulong hash = StableHash.Of(key);
        int low = 0, high = ring.Length;
        while (low < high)
        {
            int middle = low + (high - low) / 2;
            if (ring[middle].Hash < hash) low = middle + 1;
            else high = middle;
        }
        return ring[low == ring.Length ? 0 : low].Node;
    }
}
static class Simulation
{
    public static string Key(int id) => id.ToString(CultureInfo.InvariantCulture);
    public static void Run(int count)
    {
        var keys = Enumerable.Range(1, count).Select(Key).ToArray();
        Compare("modulo", new ModuloRouter(4), new ModuloRouter(5), keys, false);
        Compare("ring 1 vnode", new RingRouter(4, 1), new RingRouter(5, 1), keys, true);
        Compare("ring 128 vnodes", new RingRouter(4, 128), new RingRouter(5, 128), keys, true);
        var router = new RingRouter(5, 128);
        var requests = new int[5];
        var random = new Random(42);
        string hot = keys[0];
        for (int i = 0; i < count; i++)
            requests[router.Locate(i < count / 2 ? hot : keys[random.Next(keys.Length)])]++;
        Console.WriteLine($"Hot key owner={router.Locate(hot)}; requests per shard: {string.Join(", ", requests)}");
        Require(requests[router.Locate(hot)] >= count / 2, "Hot key traffic disappeared.");
        Console.WriteLine("Simulation checks passed.");
    }
    private static void Compare(string label, IRouter before, IRouter after, string[] keys, bool ring)
    {
        int moved = 0, oldToOld = 0;
        var counts4 = new int[4];
        var counts5 = new int[5];
        foreach (string key in keys)
        {
            int a = before.Locate(key), b = after.Locate(key);
            Require(a >= 0 && a < 4 && b >= 0 && b < 5, "Invalid routing.");
            Require(before.Locate(key) == a && after.Locate(key) == b, "Routing is not deterministic.");
            counts4[a]++;
            counts5[b]++;
            if (a != b) { moved++; if (b < 4) oldToOld++; }
        }
        Require(counts4.Sum() == keys.Length && counts5.Sum() == keys.Length, "Key count mismatch.");
        Require(!ring || oldToOld == 0, "Adding a ring node must not move keys between existing nodes.");
        Require(!ring || moved == counts5[4], "All ring movement must be to new node.");
        Console.WriteLine($"{label}: moved={moved}/{keys.Length} ({100.0*moved/keys.Length:F2}%); old-to-old={oldToOld}");
        Console.WriteLine($"  4 shards: {string.Join(", ", counts4)}; imbalance max/mean={counts4.Max()/(keys.Length/4.0):F2}");
        Console.WriteLine($"  5 shards: {string.Join(", ", counts5)}; imbalance max/mean={counts5.Max()/(keys.Length/5.0):F2}");
    }
    public static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
}
