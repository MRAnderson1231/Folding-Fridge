import Foundation

struct DetectedIngredient: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let confidence: Double
    let note: String?

    init(id: UUID = UUID(), name: String, confidence: Double, note: String? = nil) {
        self.id = id
        self.name = name
        self.confidence = confidence
        self.note = note
    }
}

struct RecipeSuggestion: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let generatedImageData: Data?
    let usedIngredients: [String]
    let pantryAssumptions: [String]
    let whyItWorks: String
    let whyHealthy: String
    let whyDelicious: String
    let timeMinutes: Int
    let steps: [String]
    let finalResultDescription: String

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        generatedImageData: Data? = nil,
        usedIngredients: [String],
        pantryAssumptions: [String],
        whyItWorks: String,
        whyHealthy: String,
        whyDelicious: String,
        timeMinutes: Int,
        steps: [String],
        finalResultDescription: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.generatedImageData = generatedImageData
        self.usedIngredients = usedIngredients
        self.pantryAssumptions = pantryAssumptions
        self.whyItWorks = whyItWorks
        self.whyHealthy = whyHealthy
        self.whyDelicious = whyDelicious
        self.timeMinutes = timeMinutes
        self.steps = steps
        self.finalResultDescription = finalResultDescription
    }
}

struct AnalysisPayload: Codable, Hashable {
    let detectedIngredients: [DetectedIngredient]
    let uncertainIngredients: [DetectedIngredient]
    let recipes: [RecipeSuggestion]
    let modelSummary: String
}

struct SavedRecipe: Codable, Hashable, Identifiable {
    let id: UUID
    let recipe: RecipeSuggestion
    let analysisPayload: AnalysisPayload?
    let imageData: Data?
    let savedAt: Date

    init(
        id: UUID = UUID(),
        recipe: RecipeSuggestion,
        analysisPayload: AnalysisPayload? = nil,
        imageData: Data? = nil,
        savedAt: Date = .now
    ) {
        self.id = id
        self.recipe = recipe
        self.analysisPayload = analysisPayload
        self.imageData = imageData
        self.savedAt = savedAt
    }
}

enum AppDestination: Hashable {
    case camera
    case profile
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct PresentedRecipeSheet: Identifiable {
    enum Source: String, Hashable {
        case generated
        case saved
    }

    let id = UUID()
    let payload: AnalysisPayload
    let imageData: Data?
    let source: Source

    var primaryRecipe: RecipeSuggestion? {
        payload.recipes.first
    }
}
