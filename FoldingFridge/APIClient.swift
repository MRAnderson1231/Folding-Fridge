import Foundation

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
    static func makeService() -> RecipeService {
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
