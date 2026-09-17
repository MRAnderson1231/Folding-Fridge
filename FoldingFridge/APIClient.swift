import Foundation
import UIKit

protocol RecipeService {
    func analyzeFridgeImage(_ imageData: Data) async throws -> AnalysisPayload
    func save(recipe: SavedRecipe) async throws
    func fetchSavedRecipes() async throws -> [SavedRecipe]
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API base URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverError(let message):
            return message.isEmpty ? "The request failed." : message
        }
    }
}

enum APIConfiguration {
    enum Supabase {
        static let projectURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        static let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
        static let enabled = !projectURL.isEmpty && !publishableKey.isEmpty
    }

    static let baseURLString = Supabase.enabled ? Supabase.projectURL : ""
    static let analyzePath = "/functions/v1/fridge-analyze"
    static let saveRecipePath = "/functions/v1/save-recipe"
    static let savedRecipesPath = "/functions/v1/my-recipes"
}

enum ServiceFactory {
    /// Uses the Supabase backend when `Info.plist` carries a project URL and key.
    /// Otherwise falls back to `DemoRecipeService`, so a clean clone runs end to
    /// end without any credentials.
    static func makeService() -> RecipeService {
        guard APIConfiguration.Supabase.enabled else {
            return DemoRecipeService()
        }
        return RemoteRecipeService(baseURLString: APIConfiguration.baseURLString)
    }
}

private struct AnalyzeRequest: Encodable {
    let imageBase64: String
}

private struct SaveRecipeRequest: Encodable {
    let recipe: SavedRecipe
}

final class RemoteRecipeService: RecipeService {
    private let baseURLString: String
    private let session: URLSession

    init(baseURLString: String, session: URLSession = .shared) {
        self.baseURLString = baseURLString
        self.session = session
    }

    func analyzeFridgeImage(_ imageData: Data) async throws -> AnalysisPayload {
        let request = try makeRequest(path: APIConfiguration.analyzePath, method: "POST", body: AnalyzeRequest(imageBase64: imageData.base64EncodedString()))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(AnalysisPayload.self, from: data)
    }

    func save(recipe: SavedRecipe) async throws {
        let request = try makeRequest(path: APIConfiguration.saveRecipePath, method: "POST", body: SaveRecipeRequest(recipe: recipe))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func fetchSavedRecipes() async throws -> [SavedRecipe] {
        let request = try makeRequest(path: APIConfiguration.savedRecipesPath, method: "GET", body: Optional<String>.none)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([SavedRecipe].self, from: data)
    }

    private func makeRequest<T: Encodable>(path: String, method: String, body: T?) throws -> URLRequest {
        guard let baseURL = URL(string: baseURLString) else {
            throw APIError.invalidURL
        }
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !APIConfiguration.Supabase.publishableKey.isEmpty {
            request.setValue(APIConfiguration.Supabase.publishableKey, forHTTPHeaderField: "apikey")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    private func validate(response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let message: String
            if let data, let body = String(data: data, encoding: .utf8), !body.isEmpty {
                message = body
            } else {
                message = "The server returned status \(http.statusCode)."
            }
            throw APIError.serverError(message)
        }
    }
}

// MARK: - Offline demo service

/// Local stand-in for the Supabase backend.
///
/// `ServiceFactory` selects this whenever `Info.plist` has no Supabase
/// configuration, which means a fresh clone runs the whole capture -> recipe
/// flow with no keys, no deployed Edge Functions and no network access.
/// Saved recipes live in memory for the lifetime of the process.
actor DemoRecipeService: RecipeService {

    /// Matches the three status messages `AppViewModel` cycles during analysis
    /// (3 x 550ms), so the loading state plays out instead of snapping.
    private let analysisDelayNanoseconds: UInt64
    private var saved: [SavedRecipe] = []

    init(analysisDelayNanoseconds: UInt64 = 1_900_000_000) {
        self.analysisDelayNanoseconds = analysisDelayNanoseconds
    }

    func analyzeFridgeImage(_ imageData: Data) async throws -> AnalysisPayload {
        try await Task.sleep(nanoseconds: analysisDelayNanoseconds)
        return DemoFixture.payload()
    }

    func save(recipe: SavedRecipe) async throws {
        saved.removeAll { $0.recipe.id == recipe.recipe.id }
        saved.insert(recipe, at: 0)
    }

    func fetchSavedRecipes() async throws -> [SavedRecipe] {
        saved
    }
}

/// Fixed analysis result used by `DemoRecipeService`.
///
/// Mirrors `supabase/functions/_shared/demo-payload.ts` so the offline path and
/// the deployed function describe the same dish. Two low-confidence items are
/// included on purpose: the detected/uncertain split is the part of the schema
/// that keeps the model from asserting ingredients it cannot actually see.
enum DemoFixture {

    static func payload() -> AnalysisPayload {
        AnalysisPayload(
            detectedIngredients: [
                DetectedIngredient(name: "Spinach", confidence: 0.98),
                DetectedIngredient(name: "Lettuce", confidence: 0.97),
                DetectedIngredient(name: "Eggs", confidence: 0.96),
                DetectedIngredient(name: "Oranges", confidence: 0.92),
                DetectedIngredient(name: "Lemons", confidence: 0.90)
            ],
            uncertainIngredients: [
                DetectedIngredient(
                    name: "Feta or similar white cheese",
                    confidence: 0.41,
                    note: "Partially hidden behind the top shelf container."
                ),
                DetectedIngredient(
                    name: "Spring onion",
                    confidence: 0.33,
                    note: "Green stems visible in the door bin, species unclear."
                )
            ],
            recipes: [recipe()],
            modelSummary: "Demo analysis reads this fridge as greens, eggs and citrus, "
                + "which supports one clean, light recipe. Two items were left in the "
                + "uncertain list rather than used in the recipe."
        )
    }

    private static func recipe() -> RecipeSuggestion {
        RecipeSuggestion(
            title: "Warm Spinach and Lettuce Egg Salad",
            subtitle: "A light, fresh dish built from the greens and eggs visible in the photo. "
                + "It uses only a few core items, needs very basic cooking, and does not depend "
                + "on complicated seasoning or difficult technique.",
            generatedImageData: coverImageData,
            usedIngredients: ["Spinach", "Lettuce", "Eggs", "Lemon or orange"],
            pantryAssumptions: ["Olive oil", "Salt", "Black pepper"],
            whyItWorks: "The fridge is already giving you a clean salad structure: tender greens, "
                + "eggs for body, and citrus for brightness.",
            whyHealthy: "It stays vegetable-forward, protein-balanced, and relies on a light "
                + "dressing rather than anything creamy or heavy.",
            whyDelicious: "Warm eggs against cool greens make the plate feel finished, while "
                + "citrus keeps it bright and fresh.",
            timeMinutes: 12,
            steps: [
                "Bring a small pot of water to a gentle boil, then cook the eggs until just set and still tender in the center.",
                "Rinse and dry the spinach and lettuce, then tear the larger leaves and spread them across a wide plate or shallow bowl.",
                "Peel the eggs and cut them in halves or thick slices while they are still slightly warm.",
                "Whisk olive oil with a squeeze of lemon or orange juice, a pinch of salt, and a little black pepper.",
                "Lay the warm eggs over the greens and spoon the citrus dressing across the top just before serving."
            ],
            finalResultDescription: "The finished dish should feel crisp, bright and light, with "
                + "soft warm eggs settling into the greens and a simple citrus dressing tying "
                + "everything together."
        )
    }

    /// Bundled dish photo, standing in for the Imagen call in the deployed function.
    private static let coverImageData: Data? = {
        UIImage(named: "GeminiCover")?.jpegData(compressionQuality: 0.9)
    }()
}
