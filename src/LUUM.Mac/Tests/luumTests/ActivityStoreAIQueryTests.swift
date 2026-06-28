import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func aiQueryRejectedErrorsMapToFriendlyMessage() {
    let message = ActivityStore.aiQueryErrorMessage(
        for: AIQueryServiceError.rejected("Token Firebase inválido ou expirado")
    )

    #expect(message == "O assistente está temporariamente indisponível.")
}

@Test
func aiQueryLocalErrorsKeepSpecificUserFacingMessage() {
    let message = ActivityStore.aiQueryErrorMessage(
        for: AIQueryServiceError.missingFirebaseAuth
    )

    #expect(message == "Entre no Luum para usar o assistente de IA.")
}
#endif
