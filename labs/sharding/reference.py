"""Independent reference for the routing algorithm; no third-party dependencies."""
from bisect import bisect_left
from collections import Counter
from hashlib import sha256


def stable_hash(value: str) -> int:
    return int.from_bytes(sha256(value.encode("utf-8")).digest()[:8], "big")


def ring(nodes: int, vnodes: int):
    entries = sorted(
        (stable_hash(f"node:{node}:vnode:{vnode}"), node, vnode)
        for node in range(nodes)
        for vnode in range(vnodes)
    )
    hashes = [entry[0] for entry in entries]
    return lambda key: entries[bisect_left(hashes, key) % len(entries)][1]


def main():
    keys = [stable_hash(str(i)) for i in range(1, 100001)]
    cases = [
        ("modulo", lambda k: k % 4, lambda k: k % 5, 79651, 59820),
        ("ring 1", ring(4, 1), ring(5, 1), 1284, 0),
        ("ring 128", ring(4, 128), ring(5, 128), 17535, 0),
    ]
    for name, before, after, expected_moved, expected_old_to_old in cases:
        owners = [(before(key), after(key)) for key in keys]
        moved = sum(a != b for a, b in owners)
        old_to_old = sum(a != b and b < 4 for a, b in owners)
        distribution = Counter(b for _, b in owners)
        assert (moved, old_to_old) == (expected_moved, expected_old_to_old)
        assert sum(distribution.values()) == len(keys)
        print(name, moved, old_to_old, sorted(distribution.items()))


if __name__ == "__main__":
    main()
