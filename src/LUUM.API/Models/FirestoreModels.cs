// File: src/LUUM.API/Models/FirestoreModels.cs
using Google.Cloud.Firestore;
using System.Collections.Generic;

namespace LUUM.API.Models
{
    [FirestoreData]
    public class User
    {
        [FirestoreDocumentId]
        public string Id { get; set; } = string.Empty;

        [FirestoreProperty]
        public string Email { get; set; } = string.Empty;

        [FirestoreProperty]
        public string DisplayName { get; set; } = string.Empty;

        [FirestoreProperty]
        public Timestamp CreatedAt { get; set; }
    }

    [FirestoreData]
    public class Session
    {
        [FirestoreDocumentId]
        public string Id { get; set; } = string.Empty;

        [FirestoreProperty]
        public string UserId { get; set; } = string.Empty;

        [FirestoreProperty]
        public Timestamp StartTime { get; set; }

        [FirestoreProperty]
        public Timestamp? EndTime { get; set; }

        [FirestoreProperty]
        public string Category { get; set; } = "Uncategorized";

        [FirestoreProperty]
    public string? AssociatedProject { get; set; }

    [FirestoreProperty]
        public List<ActivityLog> Activities { get; set; } = new();
    }

    [FirestoreData]
    public class ActivityLog
    {
        [FirestoreDocumentId]
        public string Id { get; set; } = string.Empty;

        [FirestoreProperty]
        public string UserId { get; set; } = string.Empty;

        [FirestoreProperty]
        public string WindowTitle { get; set; } = string.Empty;

        [FirestoreProperty]
        public string Category { get; set; } = string.Empty;

        [FirestoreProperty]
        public Timestamp Timestamp { get; set; }

        [FirestoreProperty]
        public bool IsProcessed { get; set; } = false;
    }

    [FirestoreData]
    public class CategoryCache
    {
        [FirestoreDocumentId]
        public string Id { get; set; } = string.Empty;

        [FirestoreProperty]
        public string TitleHash { get; set; } = string.Empty;

        [FirestoreProperty]
        public string Category { get; set; } = string.Empty;
    }
}