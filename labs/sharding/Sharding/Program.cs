using System.Globalization;
CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
try
{
    string mode = args.Length > 0 ? args[0] : "simulate";
    if (mode != "simulate" || args.Length > 2) throw new ArgumentException("Usage: simulate [keys]");
    int count = args.Length > 1 ? int.Parse(args[1], CultureInfo.InvariantCulture) : 100_000;
    if (count < 100 || count > 1_000_000) throw new ArgumentOutOfRangeException(nameof(count));
    Simulation.Run(count);
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex);
    return 1;
}
