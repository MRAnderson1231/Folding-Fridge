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
        guard let imageData = image.jpegData(compressionQuality: 0.92) else {
            statusTask?.cancel()
            errorMessage = "The captured photo could not be prepared for analysis."
            return
        }

        do {
            let payload = try await service.analyzeFridgeImage(imageData)
            statusTask?.cancel()
            withAnimation(.easeInOut(duration: 0.45)) {
                analysisPayload = payload
                HapticManager.success()
                presentedRecipeSheet = PresentedRecipeSheet(
                    payload: payload,
                    imageData: imageData,
                    source: .generated
                )
                lastPresentedRecipeSource = .generated
                capturedImage = nil
                errorMessage = nil
            }
        } catch {
            statusTask?.cancel()
            withAnimation(.easeInOut(duration: 0.35)) {
                capturedImage = nil
                analyzedImage = nil
                errorMessage = error.localizedDescription.isEmpty ? "Analysis failed." : error.localizedDescription
            }
        }
    }

    private func cycleStatusMessages() async {
        let statuses = [
            "Reading ingredients",
            "Finding the strongest dish",
            "Finishing the recipe notes"
        ]

        for status in statuses {
            guard !Task.isCancelled else { return }
            analysisStatus = status
            try? await Task.sleep(nanoseconds: 550_000_000)
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
