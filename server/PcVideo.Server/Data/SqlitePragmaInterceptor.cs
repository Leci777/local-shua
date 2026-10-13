using System.Data.Common;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace PcVideo.Server.Data;

/// <summary>
/// 给每个 SQLite 连接设 PRAGMA。EF Core 的连接池会复用连接，
/// 所以在连接打开时统一设一次就行（架构未列，属于本机性能口径的补充）。
/// </summary>
public class SqlitePragmaInterceptor : DbConnectionInterceptor
{
    private const string Pragmas = "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=5000; PRAGMA cache_size=-16000;";

    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData)
    {
        if (connection is SqliteConnection sqlite)
        {
            using var command = sqlite.CreateCommand();
            command.CommandText = Pragmas;
            command.ExecuteNonQuery();
        }
    }
}