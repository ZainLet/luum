using Google.Cloud.Firestore;
using System;
using System.Text.Json;

namespace LUUM.API.Models
{
    [FirestoreData]
    public class CloudBackupRecord
    {
        [FirestoreDocumentId]
        public string Id { get; set; } = string.Empty;

        [FirestoreProperty]
        public string BackupId { get; set; } = string.Empty;

        [FirestoreProperty]
        public string SecretHash { get; set; } = string.Empty;

        [FirestoreProperty]
        public string PayloadJson { get; set; } = "{}";

        [FirestoreProperty]
        public int SchemaVersion { get; set; } = 1;

        [FirestoreProperty]
        public string DeviceName { get; set; } = string.Empty;

        [FirestoreProperty]
        public Timestamp ExportedAt { get; set; } = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Utc));

        [FirestoreProperty]
        public Timestamp UpdatedAt { get; set; } = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Utc));
    }

    public class CloudSyncSaveRequest
    {
        public string BackupSecret { get; set; } = string.Empty;
        public JsonElement Payload { get; set; }
    }

    public class CloudSyncRestoreRequest
    {
        public string BackupSecret { get; set; } = string.Empty;
    }

    public class CloudSyncSnapshotResponse
    {
        public JsonElement? Payload { get; set; }
        public DateTimeOffset? UpdatedAt { get; set; }
    }

    public class CloudSyncErrorResponse
    {
        public string Message { get; set; } = string.Empty;
    }
}
