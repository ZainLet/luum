// File: src/LUUM.API/Services/FirestoreService.cs
using Google.Api.Gax;
using Google.Cloud.Firestore;
using LUUM.API.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

namespace LUUM.API.Services
{
    public class FirestoreService
    {
        private readonly FirestoreDb _db;
        private readonly ILogger<FirestoreService> _logger;

        public FirestoreService(IOptions<FirestoreSettings> firestoreSettings, ILogger<FirestoreService> logger)
        {
            _logger = logger;
            var settings = firestoreSettings.Value;

            var builder = new FirestoreDbBuilder
            {
                ProjectId = settings.ProjectId,
                EmulatorDetection = settings.UseEmulator ? EmulatorDetection.EmulatorOnly : EmulatorDetection.None,
            };

            if (settings.UseEmulator)
            {
                Environment.SetEnvironmentVariable("FIRESTORE_EMULATOR_HOST", $"{settings.EmulatorHost}:{settings.EmulatorPort}");
                _logger.LogInformation("Firestore Service: Using Emulator at {Host}:{Port}", settings.EmulatorHost, settings.EmulatorPort);
            }
            else
            {
                _logger.LogInformation("Firestore Service: Connecting to production project {ProjectId}", settings.ProjectId);
            }

            _db = builder.Build();
        }

        public async Task<string> CreateSessionAsync(Session session)
        {
            try
            {
                var collection = _db.Collection("sessions");
                var docRef = await collection.AddAsync(session);
                _logger.LogInformation("Created new session with ID: {SessionId} for User: {UserId}", docRef.Id, session.UserId);
                return docRef.Id;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create a new session.");
                throw;
            }
        }

        public async Task<Session?> GetSessionAsync(string sessionId)
        {
            try
            {
                var docRef = _db.Collection("sessions").Document(sessionId);
                var snapshot = await docRef.GetSnapshotAsync();
                if (snapshot.Exists)
                {
                    _logger.LogInformation("Session {SessionId} found.", sessionId);
                    return snapshot.ConvertTo<Session>();
                }
                
                _logger.LogWarning("Session {SessionId} not found.", sessionId);
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to retrieve session {SessionId}.", sessionId);
                throw;
            }
        }

        public async Task<string> AddDocumentAsync<T>(string collectionName, T document)
        {
            try
            {
                var docRef = await _db.Collection(collectionName).AddAsync(document);
                _logger.LogInformation("Added new document to {CollectionName} with ID: {DocumentId}", collectionName, docRef.Id);
                return docRef.Id;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to add document to collection {CollectionName}.", collectionName);
                throw;
            }
        }
        
        public async Task<string> GetCategoryFromCache(string windowTitle)
        {
            var titleHash = GetStableHash(windowTitle);
            var snapshot = await _db.Collection("categoryCache").Document(titleHash).GetSnapshotAsync();
            
            if (snapshot.Exists)
            {
                var cacheEntry = snapshot.ConvertTo<CategoryCache>();
                _logger.LogInformation("Cache hit for '{WindowTitle}'. Category: {Category}", windowTitle, cacheEntry.Category);
                return cacheEntry.Category;
            }

            _logger.LogInformation("Cache miss for '{WindowTitle}'.", windowTitle);
            return "Uncategorized-Cache-Miss";
        }

        public async Task SaveCategoryToCache(string windowTitle, string category)
        {
            var titleHash = GetStableHash(windowTitle);
            var cacheEntry = new CategoryCache
            {
                Id = titleHash,
                TitleHash = titleHash,
                Category = category
            };
            
            await _db.Collection("categoryCache").Document(titleHash).SetAsync(cacheEntry);
            _logger.LogInformation("Saved category '{Category}' to cache for '{WindowTitle}'.", category, windowTitle);
        }

        private string GetStableHash(string input)
        {
            using (var sha256 = System.Security.Cryptography.SHA256.Create())
            {
                var bytes = System.Text.Encoding.UTF8.GetBytes(input);
                var hashBytes = sha256.ComputeHash(bytes);
                return BitConverter.ToString(hashBytes).Replace("-", string.Empty).ToLower();
            }
        }

        // NOVO MÉTODO PARA A INTERFACE GRÁFICA
        public async Task<List<Session>> GetSessionsForUserAsync(string userId)
        {
            var query = _db.Collection("sessions").WhereEqualTo("UserId", userId);
            var snapshots = await query.GetSnapshotAsync();
            return snapshots.Documents.Select(doc => doc.ConvertTo<Session>()).ToList();
        }

        public async Task<DateTimeOffset> SaveCloudBackupAsync(string backupId, string backupSecret, string payloadJson)
        {
            var normalizedBackupId = NormalizeBackupId(backupId);
            var now = DateTimeOffset.UtcNow;
            var metadata = ExtractBackupMetadata(payloadJson, now);
            var record = new CloudBackupRecord
            {
                Id = GetStableHash(normalizedBackupId),
                BackupId = normalizedBackupId,
                SecretHash = GetStableHash(NormalizeSecret(backupSecret)),
                PayloadJson = payloadJson,
                SchemaVersion = metadata.SchemaVersion,
                DeviceName = metadata.DeviceName,
                ExportedAt = Timestamp.FromDateTimeOffset(metadata.ExportedAt),
                UpdatedAt = Timestamp.FromDateTimeOffset(now)
            };

            await _db.Collection("cloudBackups").Document(record.Id).SetAsync(record);
            _logger.LogInformation("Saved cloud backup {BackupId} from {DeviceName}.", normalizedBackupId, metadata.DeviceName);
            return now;
        }

        public async Task<CloudBackupRecord?> GetCloudBackupAsync(string backupId)
        {
            var normalizedBackupId = NormalizeBackupId(backupId);
            var snapshot = await _db.Collection("cloudBackups").Document(GetStableHash(normalizedBackupId)).GetSnapshotAsync();

            if (!snapshot.Exists)
            {
                _logger.LogInformation("Cloud backup {BackupId} was not found.", normalizedBackupId);
                return null;
            }

            return snapshot.ConvertTo<CloudBackupRecord>();
        }

        public bool BackupSecretMatches(string backupSecret, string storedHash)
        {
            var normalizedSecret = NormalizeSecret(backupSecret);
            if (string.IsNullOrWhiteSpace(normalizedSecret) || string.IsNullOrWhiteSpace(storedHash))
            {
                return false;
            }

            var incomingHashBytes = Encoding.UTF8.GetBytes(GetStableHash(normalizedSecret));
            var storedHashBytes = Encoding.UTF8.GetBytes(storedHash.Trim().ToLowerInvariant());
            return CryptographicOperations.FixedTimeEquals(incomingHashBytes, storedHashBytes);
        }

        private static string NormalizeBackupId(string backupId)
        {
            return backupId.Trim();
        }

        private static string NormalizeSecret(string backupSecret)
        {
            return backupSecret.Trim();
        }

        private static (int SchemaVersion, string DeviceName, DateTimeOffset ExportedAt) ExtractBackupMetadata(string payloadJson, DateTimeOffset fallbackTimestamp)
        {
            try
            {
                using var document = JsonDocument.Parse(payloadJson);
                var root = document.RootElement;

                var schemaVersion = root.TryGetProperty("schemaVersion", out var schemaVersionElement) &&
                    schemaVersionElement.ValueKind == JsonValueKind.Number &&
                    schemaVersionElement.TryGetInt32(out var parsedSchemaVersion)
                    ? parsedSchemaVersion
                    : 1;

                var deviceName = root.TryGetProperty("deviceName", out var deviceNameElement) &&
                    deviceNameElement.ValueKind == JsonValueKind.String
                    ? deviceNameElement.GetString() ?? string.Empty
                    : string.Empty;

                var exportedAt = root.TryGetProperty("exportedAt", out var exportedAtElement) &&
                    exportedAtElement.ValueKind == JsonValueKind.String &&
                    DateTimeOffset.TryParse(exportedAtElement.GetString(), out var parsedExportedAt)
                    ? parsedExportedAt
                    : fallbackTimestamp;

                return (schemaVersion, deviceName, exportedAt);
            }
            catch
            {
                return (1, string.Empty, fallbackTimestamp);
            }
        }
    }
}
