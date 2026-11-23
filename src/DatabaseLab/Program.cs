using Npgsql;

namespace DatabaseLab;

/// <summary>
/// Laboratório didático: provoca uma race condition e compara com uma transação correta.
/// NÃO reutilize o modo unsafe em uma aplicação real.
/// </summary>
internal static class Program
{
    private const string DefaultConnection =
        "Host=localhost;Port=5433;Username=lab;Password=lab_dev_only;Database=database_lab;Timeout=10";

    private static async Task<int> Main(string[] args)
    {
        if (args.Length is < 1 or > 2 || args[0] is not ("unsafe" or "atomic"))
        {
            PrintUsage();
            return 1;
        }

        var mode = args[0];
        var workers = 10;
        if (args.Length == 2 && !int.TryParse(args[1], out workers))
        {
            PrintUsage();
            return 1;
        }

        if (workers is < 2 or > 20)
        {
            Console.Error.WriteLine("Informe entre 2 e 20 concorrentes.");
            return 1;
        }

        var connectionString = Environment.GetEnvironmentVariable("DATABASE_LAB_CONNECTION")
                               ?? DefaultConnection;

        try
        {
            await using var dataSource = NpgsqlDataSource.Create(connectionString);
            await ResetDemoAsync(dataSource);

            Console.WriteLine($"Modo: {mode} | Concorrentes: {workers} | Estoque inicial: 1");
            var results = await (mode == "unsafe"
                ? RunUnsafeAsync(dataSource, workers)
                : RunAtomicAsync(dataSource, workers));

            var accepted = results.Count(result => result);
            var (stock, purchases) = await ReadResultAsync(dataSource);

            Console.WriteLine($"Compras aceitas: {accepted}");
            Console.WriteLine($"Compras gravadas: {purchases}");
            Console.WriteLine($"Estoque final: {stock}");

            if (mode == "unsafe")
            {
                Console.WriteLine("Este modo demonstra a falha: vários clientes podem comprar 1 unidade.");
                Console.WriteLine("A leitura inicial ficou sincronizada para tornar a disputa reproduzível.");
                return accepted > 1 && purchases > 1 && stock == 0 ? 0 : 3;
            }

            var consistent = accepted == 1 && purchases == 1 && stock == 0;
            Console.WriteLine(consistent
                ? "OK: apenas uma compra foi confirmada."
                : "FALHA: as invariantes esperadas não foram preservadas.");
            return consistent ? 0 : 3;
        }
        catch (PostgresException ex)
        {
            Console.Error.WriteLine($"Erro PostgreSQL ({ex.SqlState}): {ex.MessageText}");
            Console.Error.WriteLine("Execute o script sql/00_schema.sql antes de iniciar.");
            return 2;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Não foi possível executar o laboratório: {ex.Message}");
            Console.Error.WriteLine("Confirme que o Docker Compose está ativo e que a porta 5433 está disponível.");
            return 2;
        }
    }

    /// <summary>
    /// Propositalmente ERRADO: todas as transações leem o estoque
    /// antes de atualizá-lo. Cada uma grava o valor absoluto 0.
    /// </summary>
    private static async Task<bool[]> RunUnsafeAsync(NpgsqlDataSource dataSource, int workers)
    {
        var allRead = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var ready = 0;

        async Task<bool> TryPurchaseAsync()
        {
            await using var connection = await dataSource.OpenConnectionAsync();
            await using var transaction = await connection.BeginTransactionAsync();
            await using var read = new NpgsqlCommand(
                "SELECT stock FROM products WHERE id = 1", connection, transaction);
            var stock = Convert.ToInt32(await read.ExecuteScalarAsync());

            if (Interlocked.Increment(ref ready) == workers)
                allRead.TrySetResult(true);
            await allRead.Task.WaitAsync(TimeSpan.FromSeconds(20));

            if (stock <= 0)
            {
                await transaction.RollbackAsync();
                return false;
            }

            await using (var update = new NpgsqlCommand(
                             "UPDATE products SET stock = @newStock WHERE id = 1", connection, transaction))
            {
                update.Parameters.AddWithValue("newStock", stock - 1);
                await update.ExecuteNonQueryAsync();
            }

            await InsertPurchaseAsync(connection, transaction);
            await transaction.CommitAsync();
            return true;
        }

        return await Task.WhenAll(Enumerable.Range(0, workers).Select(_ => TryPurchaseAsync()));
    }

    /// <summary>
    /// Correto: diminuir estoque condicionalmente e inserir a compra
    /// ocorrem na mesma transação.
    /// </summary>
    private static async Task<bool[]> RunAtomicAsync(NpgsqlDataSource dataSource, int workers)
    {
        var start = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var ready = 0;

        async Task<bool> TryPurchaseAsync()
        {
            await using var connection = await dataSource.OpenConnectionAsync();
            if (Interlocked.Increment(ref ready) == workers)
                start.TrySetResult(true);
            await start.Task.WaitAsync(TimeSpan.FromSeconds(20));

            await using var transaction = await connection.BeginTransactionAsync();
            await using var update = new NpgsqlCommand(
                "UPDATE products SET stock = stock - 1, version = version + 1 " +
                "WHERE id = 1 AND stock > 0 RETURNING stock", connection, transaction);
            var newStock = await update.ExecuteScalarAsync();
            if (newStock is null)
            {
                await transaction.RollbackAsync();
                return false;
            }

            await InsertPurchaseAsync(connection, transaction);
            await transaction.CommitAsync();
            return true;
        }

        return await Task.WhenAll(Enumerable.Range(0, workers).Select(_ => TryPurchaseAsync()));
    }

    private static async Task InsertPurchaseAsync(NpgsqlConnection connection, NpgsqlTransaction transaction)
    {
        await using var insert = new NpgsqlCommand(
            "INSERT INTO purchases (product_id, quantity) VALUES (1, 1)", connection, transaction);
        await insert.ExecuteNonQueryAsync();
    }

    private static async Task ResetDemoAsync(NpgsqlDataSource dataSource)
    {
        await using var connection = await dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using (var remove = new NpgsqlCommand("DELETE FROM purchases", connection, transaction))
            await remove.ExecuteNonQueryAsync();
        await using (var restore = new NpgsqlCommand(
                         "UPDATE products SET stock = 1, version = 1 WHERE id = 1", connection, transaction))
        {
            if (await restore.ExecuteNonQueryAsync() != 1)
                throw new InvalidOperationException("Produto de teste não encontrado. Execute sql/00_schema.sql.");
        }
        await transaction.CommitAsync();
    }

    private static async Task<(int stock, long purchases)> ReadResultAsync(NpgsqlDataSource dataSource)
    {
        await using var connection = await dataSource.OpenConnectionAsync();
        await using var stockCommand = new NpgsqlCommand("SELECT stock FROM products WHERE id = 1", connection);
        await using var countCommand = new NpgsqlCommand("SELECT count(*) FROM purchases", connection);
        var stock = Convert.ToInt32(await stockCommand.ExecuteScalarAsync());
        var count = Convert.ToInt64(await countCommand.ExecuteScalarAsync());
        return (stock, count);
    }

    private static void PrintUsage()
    {
        Console.WriteLine("Uso: dotnet run --project src/DatabaseLab -- <unsafe|atomic> [concorrentes]");
        Console.WriteLine("Exemplos:");
        Console.WriteLine("  dotnet run --project src/DatabaseLab -- unsafe 10");
        Console.WriteLine("  dotnet run --project src/DatabaseLab -- atomic 10");
        Console.WriteLine("Cada execução reinicia o estoque de demonstração para 1 e apaga compras anteriores.");
    }
}
