using Google.Cloud.Firestore;
using System;
using System.Collections.Generic;

namespace LUUM.API.Models
{
    [FirestoreData]
    public class WorkspaceRecord
    {
        [FirestoreDocumentId]
        public string Id { get; set; } = string.Empty;

        [FirestoreProperty]
        public string WorkspaceId { get; set; } = string.Empty;

        [FirestoreProperty]
        public string OrganizationName { get; set; } = string.Empty;

        [FirestoreProperty]
        public string SecretHash { get; set; } = string.Empty;

        [FirestoreProperty]
        public Timestamp UpdatedAt { get; set; } = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Utc));
    }

    [FirestoreData]
    public class WorkspaceMemberRecord
    {
        [FirestoreDocumentId]
        public string Id { get; set; } = string.Empty;

        [FirestoreProperty]
        public string WorkspaceId { get; set; } = string.Empty;

        [FirestoreProperty]
        public string MemberId { get; set; } = string.Empty;

        [FirestoreProperty]
        public string DisplayName { get; set; } = string.Empty;

        [FirestoreProperty]
        public string RoleLabel { get; set; } = string.Empty;

        [FirestoreProperty]
        public double TrackedTime { get; set; }

        [FirestoreProperty]
        public double FocusTime { get; set; }

        [FirestoreProperty]
        public double PlannedTime { get; set; }

        [FirestoreProperty]
        public int ContextSwitches { get; set; }

        [FirestoreProperty]
        public int Score { get; set; }

        [FirestoreProperty]
        public Timestamp SnapshotDay { get; set; } = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Utc));

        [FirestoreProperty]
        public Timestamp WeekStart { get; set; } = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Utc));

        [FirestoreProperty]
        public Timestamp WeekEnd { get; set; } = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Utc));

        [FirestoreProperty]
        public Timestamp UpdatedAt { get; set; } = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Utc));
    }

    public class WorkspaceMemberSnapshotPayload
    {
        public string OrganizationName { get; set; } = string.Empty;
        public string MemberDisplayName { get; set; } = string.Empty;
        public string RoleLabel { get; set; } = string.Empty;
        public double TrackedTime { get; set; }
        public double FocusTime { get; set; }
        public double PlannedTime { get; set; }
        public int ContextSwitches { get; set; }
        public int Score { get; set; }
        public DateTimeOffset SnapshotDay { get; set; }
        public DateTimeOffset WeekStart { get; set; }
        public DateTimeOffset WeekEnd { get; set; }
    }

    public class WorkspaceSyncSaveRequest
    {
        public string WorkspaceSecret { get; set; } = string.Empty;
        public WorkspaceMemberSnapshotPayload Payload { get; set; } = new();
    }

    public class WorkspaceRankingRequest
    {
        public string WorkspaceSecret { get; set; } = string.Empty;
        public string RequestingMemberId { get; set; } = string.Empty;
    }

    public class WorkspaceSyncSaveResponse
    {
        public DateTimeOffset? UpdatedAt { get; set; }
    }

    public class WorkspaceRankingEntryResponse
    {
        public string Id { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string RoleLabel { get; set; } = string.Empty;
        public double TrackedTime { get; set; }
        public double FocusTime { get; set; }
        public double PlannedTime { get; set; }
        public int ContextSwitches { get; set; }
        public int Score { get; set; }
        public bool IsCurrentUser { get; set; }
    }

    public class WorkspaceRankingResponse
    {
        public string? OrganizationName { get; set; }
        public DateTimeOffset? UpdatedAt { get; set; }
        public List<WorkspaceRankingEntryResponse> Entries { get; set; } = new();
    }

    public class WorkspaceErrorResponse
    {
        public string Message { get; set; } = string.Empty;
    }
}
