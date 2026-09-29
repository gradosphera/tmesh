using Azure;
using Azure.Storage.Blobs;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using TBot;

namespace TBot.Services;

public class SQLiteBackupService(
    IOptions<TBotOptions> options,
    ILogger<SQLiteBackupService> logger)
{
    private readonly TBotOptions _options = options.Value;

    public async Task BackupAsync()
    {
        var backupOptions = _options.AzureBlobBackup;

        if (backupOptions == null
            || string.IsNullOrWhiteSpace(backupOptions.ConnectionString)
            || backupOptions.BackupPath == null
            || string.IsNullOrWhiteSpace(backupOptions.BackupPath.ContainerName)
            || string.IsNullOrWhiteSpace(backupOptions.BackupPath.BlobPath))
        {
            logger.LogInformation("SQLite backup is not configured. Skipping blob upload.");
            return;
        }

        if (string.IsNullOrWhiteSpace(_options.SQLiteConnectionString))
        {
            logger.LogWarning("SQLite backup skipped because SQLiteConnectionString is missing.");
            return;
        }

        var sqliteConnectionStringBuilder = new SqliteConnectionStringBuilder(_options.SQLiteConnectionString);
        var databasePath = sqliteConnectionStringBuilder.DataSource;
        if (string.IsNullOrWhiteSpace(databasePath))
        {
            logger.LogWarning("SQLite backup skipped because the connection string does not specify a database file.");
            return;
        }

        databasePath = Path.GetFullPath(databasePath);
        if (!File.Exists(databasePath))
        {
            logger.LogWarning("SQLite backup skipped because database file does not exist at {DatabasePath}.", databasePath);
            return;
        }

        var blobServiceClient = new BlobServiceClient(backupOptions.ConnectionString);
        var containerClient = blobServiceClient.GetBlobContainerClient(backupOptions.BackupPath.ContainerName);
        await containerClient.CreateIfNotExistsAsync();

        var blobClient = containerClient.GetBlobClient(backupOptions.BackupPath.BlobPath);
        var skipIfUpdatedLessThan = TimeSpan.FromHours(backupOptions.SkipIfBlobUpdatedLessThanHours);
        if (skipIfUpdatedLessThan > TimeSpan.Zero)
        {
            try
            {
                var blobProperties = await blobClient.GetPropertiesAsync();
                var lastModified = blobProperties.Value.LastModified;
                var age = DateTimeOffset.UtcNow - lastModified;

                if (age < skipIfUpdatedLessThan)
                {
                    logger.LogInformation(
                        "Skipping SQLite backup because blob {ContainerName}/{BlobPath} was last updated {LastModifiedUtc} ({Age}) ago, which is less than the configured threshold of {ThresholdHours} hours.",
                        backupOptions.BackupPath.ContainerName,
                        backupOptions.BackupPath.BlobPath,
                        lastModified,
                        age,
                        backupOptions.SkipIfBlobUpdatedLessThanHours);
                    return;
                }
            }
            catch (RequestFailedException ex) when (ex.Status == 404)
            {
                // Blob does not exist yet, proceed with upload.
            }
        }

        await using var stream = new FileStream(databasePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        await blobClient.UploadAsync(stream, overwrite: true);

        logger.LogInformation("Uploaded SQLite database backup to Azure Blob Storage at {ContainerName}/{BlobPath}.",
            backupOptions.BackupPath.ContainerName,
            backupOptions.BackupPath.BlobPath);
    }
}
