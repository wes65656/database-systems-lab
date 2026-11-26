namespace StorageEngines;

internal sealed class BTree
{
    private sealed class Page
    {
        public List<int> Keys { get; } = [];
        public List<Page> Children { get; } = [];
    }

    private readonly int degree;
    private Page root = new();

    public BTree(int degree)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(degree, 2);
        this.degree = degree;
    }

    public int Splits { get; private set; }
    public int Height { get; private set; } = 1;

    public bool Contains(int key)
    {
        Page page = root;
        while (true)
        {
            int index = page.Keys.BinarySearch(key);
            if (index >= 0)
                return true;
            if (page.Children.Count == 0)
                return false;
            page = page.Children[~index];
        }
    }

    public bool Insert(int key)
    {
        if (Contains(key))
            return false;
        if (IsFull(root))
        {
            var parent = new Page();
            parent.Children.Add(root);
            Split(parent, 0);
            root = parent;
            Height++;
        }

        Page page = root;
        while (true)
        {
            int index = ~page.Keys.BinarySearch(key);
            if (page.Children.Count == 0)
            {
                page.Keys.Insert(index, key);
                return true;
            }
            if (IsFull(page.Children[index]))
            {
                Split(page, index);
                if (key > page.Keys[index])
                    index++;
            }
            page = page.Children[index];
        }
    }

    private bool IsFull(Page page) => page.Keys.Count == 2L * degree - 1;

    private void Split(Page parent, int index)
    {
        Page left = parent.Children[index];
        var right = new Page();
        int median = left.Keys[degree - 1];
        right.Keys.AddRange(left.Keys.GetRange(degree, degree - 1));
        left.Keys.RemoveRange(degree - 1, degree);
        if (left.Children.Count != 0)
        {
            right.Children.AddRange(left.Children.GetRange(degree, degree));
            left.Children.RemoveRange(degree, degree);
        }
        parent.Keys.Insert(index, median);
        parent.Children.Insert(index + 1, right);
        Splits++;
    }

    public IEnumerable<int> Scan() => Scan(root);

    private static IEnumerable<int> Scan(Page page)
    {
        for (int index = 0; index <= page.Keys.Count; index++)
        {
            if (page.Children.Count != 0)
                foreach (int childKey in Scan(page.Children[index]))
                    yield return childKey;
            if (index < page.Keys.Count)
                yield return page.Keys[index];
        }
    }
}
