import Foundation

enum BusinessBillingModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case hourly
    case retainer
    case fixedFee
    case hybrid
    case internalWork
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hourly: "Por hora"
        case .retainer: "Retainer"
        case .fixedFee: "Projeto fechado"
        case .hybrid: "Hibrido"
        case .internalWork: "Interno"
        case .custom: "Customizado"
        }
    }
}

enum ContractPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case monthly
    case quarterly
    case annual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Mensal"
        case .quarterly: "Trimestral"
        case .annual: "Anual"
        }
    }
}

enum BusinessExpenseCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case adSpend
    case vendor
    case freelancer
    case software
    case other

    var id: String { rawValue }
}

enum BusinessExpenseType: String, Codable, CaseIterable, Identifiable, Sendable {
    case passThrough
    case delivery
    case overhead

    var id: String { rawValue }
}

enum BusinessRevenueCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case setupFee
    case consulting
    case upsell
    case adjustment
    case other

    var id: String { rawValue }
}

struct WorkTaskProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var status: String
    var isBillable: Bool

    init(id: UUID = UUID(), title: String, status: String = "active", isBillable: Bool = true) {
        self.id = id
        self.title = title
        self.status = status
        self.isBillable = isBillable
    }
}

struct WorkProjectProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var clientID: UUID
    var title: String
    var status: String
    var hourlyRate: Double
    var budgetAmount: Double
    var tasks: [WorkTaskProfile]

    init(
        id: UUID = UUID(),
        clientID: UUID,
        title: String,
        status: String = "active",
        hourlyRate: Double = 0,
        budgetAmount: Double = 0,
        tasks: [WorkTaskProfile] = []
    ) {
        self.id = id
        self.clientID = clientID
        self.title = title
        self.status = status
        self.hourlyRate = hourlyRate
        self.budgetAmount = budgetAmount
        self.tasks = tasks
    }
}

struct ClientContractProfile: Codable, Hashable, Sendable {
    var billingModel: BusinessBillingModel
    var period: ContractPeriod
    var retainerAmount: Double
    var defaultHourlyRate: Double

    static let `default` = ClientContractProfile(
        billingModel: .hourly,
        period: .monthly,
        retainerAmount: 0,
        defaultHourlyRate: 0
    )
}

struct WorkClientProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var status: String
    var domain: String
    var contract: ClientContractProfile

    init(
        id: UUID = UUID(),
        name: String,
        status: String = "active",
        domain: String = "",
        contract: ClientContractProfile = .default
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.domain = domain
        self.contract = contract
    }
}

struct BusinessWorkspaceSettings: Codable, Hashable, Sendable {
    var clients: [WorkClientProfile]
    var projects: [WorkProjectProfile]
    var defaultExpenseCategories: [BusinessExpenseCategory]
    var defaultExpenseTypes: [BusinessExpenseType]
    var defaultRevenueCategories: [BusinessRevenueCategory]

    static let `default` = BusinessWorkspaceSettings(
        clients: [],
        projects: [],
        defaultExpenseCategories: BusinessExpenseCategory.allCases,
        defaultExpenseTypes: BusinessExpenseType.allCases,
        defaultRevenueCategories: BusinessRevenueCategory.allCases
    )

    var activeClients: [WorkClientProfile] {
        clients.filter { $0.status == "active" }
    }

    var activeProjects: [WorkProjectProfile] {
        projects.filter { $0.status == "active" }
    }

    var billableProjectsCount: Int {
        projects.filter { $0.hourlyRate > 0 || $0.budgetAmount > 0 }.count
    }

    var estimatedMonthlyRevenue: Double {
        clients.reduce(0) { result, client in
            guard client.status == "active" else { return result }
            switch client.contract.billingModel {
            case .retainer, .hybrid:
                return result + max(0, client.contract.retainerAmount)
            default:
                return result
            }
        }
    }

    func normalized() -> BusinessWorkspaceSettings {
        var seenClientIDs = Set<UUID>()
        let normalizedClients = clients.compactMap { client -> WorkClientProfile? in
            let name = client.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seenClientIDs.insert(client.id).inserted else { return nil }

            var contract = client.contract
            contract.retainerAmount = max(0, contract.retainerAmount)
            contract.defaultHourlyRate = max(0, contract.defaultHourlyRate)

            return WorkClientProfile(
                id: client.id,
                name: name,
                status: client.status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "active" : client.status.trimmingCharacters(in: .whitespacesAndNewlines),
                domain: client.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                contract: contract
            )
        }

        let validClientIDs = Set(normalizedClients.map(\.id))
        var seenProjectIDs = Set<UUID>()
        let normalizedProjects = projects.compactMap { project -> WorkProjectProfile? in
            let title = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty,
                  validClientIDs.contains(project.clientID),
                  seenProjectIDs.insert(project.id).inserted
            else { return nil }

            var seenTaskIDs = Set<UUID>()
            let tasks = project.tasks.compactMap { task -> WorkTaskProfile? in
                let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, seenTaskIDs.insert(task.id).inserted else { return nil }
                return WorkTaskProfile(
                    id: task.id,
                    title: title,
                    status: task.status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "active" : task.status.trimmingCharacters(in: .whitespacesAndNewlines),
                    isBillable: task.isBillable
                )
            }

            return WorkProjectProfile(
                id: project.id,
                clientID: project.clientID,
                title: title,
                status: project.status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "active" : project.status.trimmingCharacters(in: .whitespacesAndNewlines),
                hourlyRate: max(0, project.hourlyRate),
                budgetAmount: max(0, project.budgetAmount),
                tasks: tasks
            )
        }

        return BusinessWorkspaceSettings(
            clients: normalizedClients.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            projects: normalizedProjects.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending },
            defaultExpenseCategories: Array(Set(defaultExpenseCategories)).sorted { $0.rawValue < $1.rawValue },
            defaultExpenseTypes: Array(Set(defaultExpenseTypes)).sorted { $0.rawValue < $1.rawValue },
            defaultRevenueCategories: Array(Set(defaultRevenueCategories)).sorted { $0.rawValue < $1.rawValue }
        )
    }
}
