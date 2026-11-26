using System.Buffers.Binary;
using System.Collections;
using System.Security.Cryptography;

namespace StorageEngines;

internal sealed class BloomFilter(int bitCount = 128)
{
    private readonly BitArray bits = new(bitCount > 0 ? bitCount : throw new ArgumentOutOfRangeException(nameof(bitCount)));

    public void Add(int key)
    {
        foreach (int position in Positions(key))
            bits[position] = true;
    }

    public bool MightContain(int key) => Positions(key).All(position => bits[position]);

    private int[] Positions(int key)
    {
        Span<byte> bytes = stackalloc byte[sizeof(int)];
        BinaryPrimitives.WriteInt32LittleEndian(bytes, key);
        byte[] hash = SHA256.HashData(bytes);
        var positions = new int[3];
        for (int index = 0; index < positions.Length; index++)
            positions[index] = (int)(BinaryPrimitives.ReadUInt32LittleEndian(hash.AsSpan(index * 4)) % (uint)bits.Length);
        return positions;
    }
}

internal sealed class LsmTree(int capacity, int bloomBits = 128)
{
    private sealed class SsTable
    {
        private readonly int[] keys;
        private readonly string?[] values;
        public BloomFilter Filter { get; }
        public int Count => keys.Length;

        public SsTable(SortedDictionary<int, string?> entries, int bloomBits)
        {
            keys = entries.Keys.ToArray();
            values = entries.Values.ToArray();
            Filter = new BloomFilter(bloomBits);
            foreach (int key in keys)
                Filter.Add(key);
        }

        public bool TryGet(int key, out string? value)
        {
            int index = Array.BinarySearch(keys, key);
            value = index >= 0 ? values[index] : null;
            return index >= 0;
        }

        public void Overlay(SortedDictionary<int, string?> target)
        {
            for (int index = 0; index < keys.Length; index++)
                target[keys[index]] = values[index];
        }
    }

    private readonly int capacity = capacity > 0 ? capacity : throw new ArgumentOutOfRangeException(nameof(capacity));
    private readonly int bloomBits = bloomBits > 0 ? bloomBits : throw new ArgumentOutOfRangeException(nameof(bloomBits));
    private readonly SortedDictionary<int, string?> memtable = [];
    private readonly List<SsTable> tables = [];

    public int TableCount => tables.Count;
    public int StoredRecords => memtable.Count + tables.Sum(table => table.Count);
    public int LiveKeys => Merge().Values.Count(value => value is not null);
    public long Mutations { get; private set; }
    public long WrittenRecords { get; private set; }
    public double? WriteAmplification => Mutations == 0 ? null : (double)WrittenRecords / Mutations;
    public double? SpaceAmplification => LiveKeys is int count && count > 0 ? (double)StoredRecords / count : null;

    public void Put(int key, string value)
    {
        ArgumentNullException.ThrowIfNull(value);
        Write(key, value);
    }

    public void Delete(int key) => Write(key, null);

    private void Write(int key, string? value)
    {
        memtable[key] = value;
        Mutations++;
        if (memtable.Count >= capacity)
            Flush();
    }

    public void Flush()
    {
        if (memtable.Count == 0)
            return;
        WriteTable(memtable);
        memtable.Clear();
    }

    public (string? Value, int Probes, int Skips, int FalsePositives) Read(int key, bool useBloom = true)
    {
        if (memtable.TryGetValue(key, out string? value))
            return (value, 0, 0, 0);

        int probes = 0;
        int skips = 0;
        for (int index = tables.Count - 1; index >= 0; index--)
        {
            SsTable table = tables[index];
            if (useBloom && !table.Filter.MightContain(key))
            {
                skips++;
                continue;
            }
            probes++;
            if (table.TryGet(key, out value))
                return (value, probes, skips, useBloom ? probes - 1 : 0);
        }
        return (null, probes, skips, useBloom ? probes : 0);
    }

    public void Compact()
    {
        if (tables.Count == 0)
            return;
        var merged = Merge();
        // A compactação cobre todas as tabelas e a memtable.
        // Assim, nenhuma versão antiga pode reaparecer após descartar um tombstone.
        foreach (int key in merged.Where(entry => entry.Value is null).Select(entry => entry.Key).ToArray())
            merged.Remove(key);
        tables.Clear();
        memtable.Clear();
        if (merged.Count != 0)
            WriteTable(merged);
    }

    private SortedDictionary<int, string?> Merge()
    {
        var merged = new SortedDictionary<int, string?>();
        foreach (SsTable table in tables)
            table.Overlay(merged);
        foreach (var entry in memtable)
            merged[entry.Key] = entry.Value;
        return merged;
    }

    private void WriteTable(SortedDictionary<int, string?> entries)
    {
        tables.Add(new SsTable(entries, bloomBits));
        WrittenRecords += entries.Count;
    }
}
