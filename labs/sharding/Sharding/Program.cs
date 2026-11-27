using System.Globalization;
CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
try
{
    string mode = args.Length > 0 ? args[0] : "simulate";
    if (mode is not ("simulate" or "real-ring" or "real-modulo") || args.Length > 2)
        throw new ArgumentException("Usage: simulate|real-ring|real-modulo [keys]");
    int count = args.Length > 1 ? int.Parse(args[1], CultureInfo.InvariantCulture) : mode == "simulate" ? 100_000 : 2_000;
    if (count < 100 || count > (mode == "simulate" ? 1_000_000 : 20_000))
        throw new ArgumentOutOfRangeException(nameof(count));
    if (mode == "simulate") Simulation.Run(count);
    else
    {
        using var cluster = new ShardCluster();
        cluster.Run(count, mode == "real-ring");
    }
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex);
    return 1;
}
