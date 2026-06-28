import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@MainActor
@Test
func weeklyReportJSONExportContainsExpectedFields() throws {
    let store = ActivityStore()
    let report = weeklyReportFixture()

    let data = try store.weeklyReportExportData(for: report, format: .json)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(json["totalTrackedTime"] as? Double == 7200)
    #expect(json["contextSwitches"] as? Int == 6)
    #expect((json["topCategories"] as? [[String: Any]])?.first?["label"] as? String == "Produto")
    #expect((json["topApps"] as? [[String: Any]])?.first?["label"] as? String == "Xcode")
    #expect((json["topSites"] as? [[String: Any]])?.first?["label"] as? String == "github.com")
    #expect((json["highlights"] as? [String])?.first == "Semana consistente de produto.")
}

@MainActor
@Test
func weeklyReportCSVExportContainsHeaderAndBreakdowns() throws {
    let store = ActivityStore()
    let report = weeklyReportFixture()

    let data = try store.weeklyReportExportData(for: report, format: .csv)
    let csv = try #require(String(data: data, encoding: .utf8))

    #expect(csv.contains("type,label,duration_minutes"))
    #expect(csv.contains("category,Produto,60"))
    #expect(csv.contains("app,Xcode,45"))
    #expect(csv.contains("site,github.com,15"))
}

private func weeklyReportFixture() -> WeeklyReport {
    let category = ActivityCategory(
        id: "product",
        title: "Produto",
        systemImage: "hammer",
        colorToken: .sky,
        isBuiltIn: false
    )

    return WeeklyReport(
        startDate: Date(timeIntervalSince1970: 1_719_158_400),
        endDate: Date(timeIntervalSince1970: 1_719_763_199),
        totalTrackedTime: 7200,
        averageDailyTrackedTime: 1028.57,
        contextSwitches: 6,
        focusTime: 5400,
        distractionTime: 900,
        topCategories: [
            CategoryBreakdown(category: category, duration: 3600),
        ],
        topApps: [
            UsageBreakdownItem(
                id: "xcode",
                label: "Xcode",
                secondaryLabel: nil,
                duration: 2700,
                category: category,
                systemImage: "hammer"
            ),
        ],
        topSites: [
            UsageBreakdownItem(
                id: "github",
                label: "github.com",
                secondaryLabel: nil,
                duration: 900,
                category: category,
                systemImage: "globe"
            ),
        ],
        goalProgress: [],
        days: [],
        highlights: ["Semana consistente de produto."]
    )
}
#endif
