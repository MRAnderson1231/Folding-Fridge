import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    private static let savedRecipesDefaultsKey = "foldingFridge.savedRecipes"
    private static let profileAvatarDefaultsKey = "foldingFridge.profileAvatarData"
    private static let profileNameDefaultsKey = "foldingFridge.profileName"
    private static let profileLocationDefaultsKey = "foldingFridge.profileLocation"
    static let defaultProfileName = "Name"
    static let defaultProfileLocation = "Address"

    @Published var hasCompletedOnboarding = false
    @Published var selectedDestination: AppDestination = .camera
    @Published var capturedImage: UIImage?
    @Published var analyzedImage: UIImage?
    @Published var analysisPayload: AnalysisPayload?
    @Published var presentedRecipeSheet: PresentedRecipeSheet?
    @Published var analysisStatus = "Reading ingredients"
    @Published var errorMessage: String?
    @Published var savedRecipes: [SavedRecipe] = []
    @Published var activeCookRecipe: RecipeSuggestion?
    @Published var sharePayload: SharePayload?
    @Published var profileAvatarData: Data?
    @Published var profileName: String
    @Published var profileLocation: String

    let cameraService = CameraService()

    private let service: RecipeService
    private var statusTask: Task<Void, Never>?
    private var lastPresentedRecipeSource: PresentedRecipeSheet.Source?
    private let presentationImageAssetName = "DemoCup"
    private let presentationDelayNanoseconds: UInt64 = 5_000_000_000

    init(service: RecipeService) {
        profileAvatarData = UserDefaults.standard.data(forKey: Self.profileAvatarDefaultsKey)
        profileName = UserDefaults.standard.string(forKey: Self.profileNameDefaultsKey) ?? Self.defaultProfileName
        profileLocation = UserDefaults.standard.string(forKey: Self.profileLocationDefaultsKey) ?? Self.defaultProfileLocation
        if let savedData = UserDefaults.standard.data(forKey: Self.savedRecipesDefaultsKey),
           let decoded = try? JSONDecoder().decode([SavedRecipe].self, from: savedData) {
            savedRecipes = decoded
        }
        self.service = service
        Task {
            await loadSavedRecipes()
        }
    }

    var needsInitialProfileSetup: Bool {
        profileAvatarData == nil &&
        profileName == Self.defaultProfileName &&
        profileLocation == Self.defaultProfileLocation
    }

    func begin() {
        cameraService.requestAccessIfNeeded()
        if cameraService.authorizationStatus == .authorized {
            cameraService.configureSessionIfNeeded()
        }

        withAnimation(.easeInOut(duration: 0.45)) {
            hasCompletedOnboarding = true
            selectedDestination = .camera
        }
    }

    func retake() {
        statusTask?.cancel()
        withAnimation(.easeInOut(duration: 0.35)) {
            capturedImage = nil
            analyzedImage = nil
            analysisPayload = nil
            presentedRecipeSheet = nil
            lastPresentedRecipeSource = nil
            errorMessage = nil
            analysisStatus = "Reading ingredients"
            selectedDestination = .camera
        }
    }

    func capture() {
        HapticManager.tap()
        Task {
            do {
                let image = try await cameraService.capturePhoto()
                processCapture(image)
            } catch CameraCaptureError.unavailable {
                errorMessage = "The simulator cannot access a real camera. Long press the shutter to choose a fridge photo from your library."
            } catch {
                errorMessage = "Unable to capture a photo right now."
            }
        }
    }

    func processCapture(_ image: UIImage) {
        statusTask?.cancel()
        capturedImage = image
        analyzedImage = image
        analysisPayload = nil
        presentedRecipeSheet = nil
        errorMessage = nil
        analysisStatus = "Reading ingredients"

        statusTask = Task { [weak self] in
            await self?.cycleStatusMessages()
        }

        Task {
            await analyze(image: image)
        }
    }

    func save(_ recipe: RecipeSuggestion) {
        guard !savedRecipes.contains(where: { $0.recipe.id == recipe.id }) else { return }
        let saved = SavedRecipe(
            recipe: recipe,
            analysisPayload: analysisPayload ?? presentedRecipeSheet?.payload,
            imageData: recipe.generatedImageData ?? (analyzedImage ?? capturedImage)?.jpegData(compressionQuality: 0.92) ?? presentedRecipeSheet?.imageData
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            savedRecipes.insert(saved, at: 0)
        }
        persistSavedRecipes()
        Task {
            try? await service.save(recipe: saved)
        }
    }

    func isSaved(_ recipe: RecipeSuggestion) -> Bool {
        savedRecipes.contains(where: { $0.recipe.id == recipe.id })
    }

    func openCookMode(for recipe: RecipeSuggestion) {
        activeCookRecipe = recipe
    }

    func dismissCookMode() {
        activeCookRecipe = nil
    }

    func makeSharePayload(for recipe: RecipeSuggestion) -> SharePayload {
        let fallbackImageData =
            recipe.generatedImageData ??
            savedRecipes.first(where: { $0.recipe.id == recipe.id })?.imageData ??
            presentedRecipeSheet?.imageData ??
            analyzedImage?.jpegData(compressionQuality: 0.9) ??
            capturedImage?.jpegData(compressionQuality: 0.9)

        let payload = AnalysisPayload(
            detectedIngredients: [],
            uncertainIngredients: [],
            recipes: [recipe],
            modelSummary: ""
        )

        let presentation = PresentedRecipeSheet(
            payload: payload,
            imageData: fallbackImageData,
            source: .saved
        )

        let renderer = ImageRenderer(
            content: RecipeShareCardView(presentation: presentation)
                .frame(width: 1080, height: 1920)
                .background(FFTheme.background)
        )
        renderer.scale = 1

        if let image = renderer.uiImage {
            HapticManager.success()
            return SharePayload(items: [image])
        } else {
            return SharePayload(items: [shareText(for: recipe)])
        }
    }

    func prepareShare(for recipe: RecipeSuggestion) {
        HapticManager.sheet()
        sharePayload = makeSharePayload(for: recipe)
    }

    func openSavedRecipe(_ savedRecipe: SavedRecipe) {
        let payload = savedRecipe.analysisPayload ?? AnalysisPayload(
            detectedIngredients: [],
            uncertainIngredients: [],
            recipes: [savedRecipe.recipe],
            modelSummary: ""
        )
        presentedRecipeSheet = PresentedRecipeSheet(
            payload: payload,
            imageData: savedRecipe.imageData,
            source: .saved
        )
        lastPresentedRecipeSource = .saved
    }

    func dismissPresentedRecipeSheet() {
        let source = lastPresentedRecipeSource
        lastPresentedRecipeSource = nil
        presentedRecipeSheet = nil

        if source == .generated {
            cameraService.configureSessionIfNeeded()

            withAnimation(.easeInOut(duration: 0.35)) {
                capturedImage = nil
                analyzedImage = nil
                analysisPayload = nil
                errorMessage = nil
                analysisStatus = "Reading ingredients"
                selectedDestination = .camera
            }
        }
    }

    func updateProfileAvatar(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return }
        profileAvatarData = data
        UserDefaults.standard.set(data, forKey: Self.profileAvatarDefaultsKey)
    }

    func updateProfileName(_ name: String) {
        profileName = name
        UserDefaults.standard.set(name, forKey: Self.profileNameDefaultsKey)
    }

    func updateProfileLocation(_ location: String) {
        profileLocation = location
        UserDefaults.standard.set(location, forKey: Self.profileLocationDefaultsKey)
    }

    private func analyze(image: UIImage) async {
        try? await Task.sleep(nanoseconds: presentationDelayNanoseconds)
        statusTask?.cancel()

        let payload = makePresentationPayload()
        let demoImageData = makePresentationImageData() ?? image.jpegData(compressionQuality: 0.92)

        withAnimation(.easeInOut(duration: 0.25)) {
            analysisPayload = payload
            analyzedImage = makePresentationUIImage() ?? image
            HapticManager.success()
            presentedRecipeSheet = PresentedRecipeSheet(
                payload: payload,
                imageData: demoImageData,
                source: .generated
            )
            lastPresentedRecipeSource = .generated
            capturedImage = nil
            errorMessage = nil
        }
    }

    private func makePresentationUIImage() -> UIImage? {
        UIImage(named: presentationImageAssetName)
    }

    private func makePresentationImageData() -> Data? {
        makePresentationUIImage()?.jpegData(compressionQuality: 0.94)
    }

    private func makePresentationPayload() -> AnalysisPayload {
        let imageData = makePresentationImageData()

        let recipe = RecipeSuggestion(
            title: "Blueberry Banana Chocolate Oat Yogurt Cup",
            subtitle: "A fresh layered yogurt cup with fruit, oats, and chocolate, designed as a quick, balanced, and visually pleasing everyday treat.",
            generatedImageData: imageData,
            usedIngredients: [
                "Banana",
                "Blueberries",
                "Oats",
                "Chocolate",
                "Milk",
                "Yogurt"
            ],
            pantryAssumptions: [],
            whyItWorks: "Banana adds softness and natural sweetness, blueberries bring brightness, oats create body, and chocolate gives the final cup a richer finish. Yogurt and milk tie everything together into a smooth layered texture.",
            whyHealthy: "It combines fruit, dairy, and oats into a light but filling option, giving the user a more balanced alternative to a processed dessert.",
            whyDelicious: "The flavor structure is simple but complete: creamy yogurt, sweet banana, bright blueberries, soft oats, and small hits of chocolate.",
            timeMinutes: 5,
            steps: [
                "Slice the banana and rinse the blueberries carefully, then set them aside for layering.",
                "Combine the oats with a small amount of milk and let them sit briefly so they soften and become smoother in texture.",
                "Spoon a layer of yogurt into the bottom of a clear glass or serving cup.",
                "Add a layer of softened oats, then place banana slices and blueberries over the top.",
                "Repeat the layering with more yogurt, oats, banana, and blueberries until the cup looks full and balanced.",
                "Finish with small chocolate pieces or chocolate shavings on the top layer, then add a few extra blueberries for a clean final look.",
                "Serve immediately, or chill briefly so the layers settle and the texture becomes slightly firmer."
            ],
            finalResultDescription: "The finished dish should look like a neat layered yogurt cup with visible white yogurt, pale oats, fresh banana slices, bright blueberries, and small dark chocolate accents. It should feel refreshing, soft, lightly indulgent, and polished enough to look like a carefully plated cafe-style breakfast."
        )

        return AnalysisPayload(
            detectedIngredients: [
                DetectedIngredient(name: "Banana", confidence: 0.99),
                DetectedIngredient(name: "Blueberries", confidence: 0.99),
                DetectedIngredient(name: "Oats", confidence: 0.98),
                DetectedIngredient(name: "Chocolate", confidence: 0.98),
                DetectedIngredient(name: "Milk", confidence: 0.97),
                DetectedIngredient(name: "Yogurt", confidence: 0.99)
            ],
            uncertainIngredients: [],
            recipes: [recipe],
            modelSummary: "Presentation build: the app currently returns a fixed yogurt cup recipe instantly for demonstration consistency."
        )
    }

    private func cycleStatusMessages() async {
        let statuses: [(String, UInt64)] = [
            ("Reading ingredients", 1_500_000_000),
            ("Finding the strongest dish", 1_500_000_000),
            ("Finishing the recipe notes", 2_000_000_000)
        ]

        for (status, duration) in statuses {
            guard !Task.isCancelled else { return }
            analysisStatus = status
            try? await Task.sleep(nanoseconds: duration)
        }
    }

    private func loadSavedRecipes() async {
        if let fetched = try? await service.fetchSavedRecipes(), !fetched.isEmpty {
            savedRecipes = fetched
            persistSavedRecipes()
        }
    }

    private func shareText(for recipe: RecipeSuggestion) -> String {
        let steps = recipe.steps.prefix(3).enumerated().map { index, step in
            "\(index + 1). \(step)"
        }.joined(separator: "\n")

        return """
        \(recipe.title)

        \(recipe.subtitle)

        Main ingredients: \(recipe.usedIngredients.joined(separator: ", "))

        \(steps)

        Shared from Folding Fridge
        """
    }

    private func persistSavedRecipes() {
        guard let encoded = try? JSONEncoder().encode(savedRecipes) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.savedRecipesDefaultsKey)
    }

}
