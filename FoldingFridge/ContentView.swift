import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ZStack {
            FFTheme.background.ignoresSafeArea()

            if appModel.hasCompletedOnboarding {
                MainShellView()
            } else {
                OnboardingView()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
            }
        }
        .sheet(item: $appModel.activeCookRecipe) { recipe in
            CookModeView(recipe: recipe)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(
            item: $appModel.presentedRecipeSheet,
            onDismiss: {
                appModel.dismissPresentedRecipeSheet()
            }
        ) { presentation in
            ResultsView(presentation: presentation)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
                .presentationBackground(FFTheme.background)
        }
        .sheet(item: $appModel.sharePayload) { payload in
            ActivityView(items: payload.items)
        }
        .onChange(of: appModel.activeCookRecipe?.id) { _, newValue in
            guard newValue != nil else { return }
            HapticManager.sheet()
        }
        .onChange(of: appModel.presentedRecipeSheet?.id) { _, newValue in
            guard newValue != nil else { return }
            HapticManager.sheet()
        }
        .onChange(of: appModel.sharePayload?.id) { _, newValue in
            guard newValue != nil else { return }
            HapticManager.sheet()
        }
    }
}

private struct MainShellView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        TabView(selection: $appModel.selectedDestination) {
            CaptureExperienceView()
                .tag(AppDestination.camera)
                .tabItem {
                    Label("Capture", systemImage: "camera.aperture")
                }

            ProfileView()
                .tag(AppDestination.profile)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .animation(.easeInOut(duration: 0.3), value: appModel.selectedDestination)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(FFTheme.background, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .task {
            if appModel.selectedDestination == .camera {
                appModel.cameraService.requestAccessIfNeeded()
                if appModel.cameraService.authorizationStatus == .authorized {
                    appModel.cameraService.configureSessionIfNeeded()
                }
            }
        }
        .onChange(of: appModel.selectedDestination) { _, destination in
            guard destination == .camera else { return }
            appModel.cameraService.requestAccessIfNeeded()
            if appModel.cameraService.authorizationStatus == .authorized {
                appModel.cameraService.configureSessionIfNeeded()
            }
        }
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var dragOffset: CGFloat = 0
    private let prototypeSize = CGSize(width: 402, height: 874)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                FFTheme.background

                collageElement(
                    imageName: "banana",
                    width: 454,
                    height: 295,
                    offsetX: -164,
                    offsetY: -339,
                    in: geometry,
                    contentMode: .fill
                )

                collageElement(
                    imageName: "apple",
                    width: 148,
                    height: 206,
                    offsetX: 110,
                    offsetY: -186,
                    in: geometry,
                    contentMode: .fill
                )

                collageElement(
                    imageName: "fish",
                    width: 404,
                    height: 166,
                    offsetX: -154,
                    offsetY: -83,
                    in: geometry,
                    contentMode: .fill
                )

                collageElement(
                    imageName: "milk",
                    width: 329,
                    height: 366,
                    offsetX: -205,
                    offsetY: 183,
                    in: geometry,
                    contentMode: .fill
                )

                VStack(alignment: .leading, spacing: scaledY(geometry, 0)) {
                    Text("capture")
                    Text("cook")
                    Text("consume")
                }
                .font(.system(size: scaledX(geometry, 44), weight: .regular, design: .default).width(.expanded))
                .foregroundStyle(Color.black)
                .frame(width: scaledX(geometry, 315), height: scaledY(geometry, 202), alignment: .topLeading)
                .position(
                    x: scaledX(geometry, 256),
                    y: scaledY(geometry, 642)
                )
                .zIndex(1)

                collageElement(
                    imageName: "orange",
                    width: 245,
                    height: 279,
                    offsetX: 171,
                    offsetY: 104,
                    in: geometry,
                    contentMode: .fill
                )
                .zIndex(2)

                OnboardingSwipeHint()
                    .position(
                        x: geometry.size.width * 0.5,
                        y: geometry.size.height * 0.925
                    )
                    .zIndex(3)
            }
            .ignoresSafeArea()
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        dragOffset = max(0, value.translation.width)
                    }
                    .onEnded { value in
                        if value.translation.width > geometry.size.width * 0.2 {
                            HapticManager.onboardingCommit()
                            appModel.begin()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
    }

    private func scaledX(_ geometry: GeometryProxy, _ value: CGFloat) -> CGFloat {
        geometry.size.width * (value / prototypeSize.width)
    }

    private func scaledY(_ geometry: GeometryProxy, _ value: CGFloat) -> CGFloat {
        geometry.size.height * (value / prototypeSize.height)
    }

    @ViewBuilder
    private func collageElement(
        imageName: String,
        width: CGFloat,
        height: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        in geometry: GeometryProxy,
        contentMode: ContentMode
    ) -> some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(
                width: scaledX(geometry, width),
                height: scaledY(geometry, height)
            )
            .clipped()
            .offset(
                x: scaledX(geometry, offsetX),
                y: scaledY(geometry, offsetY)
            )
    }
}

private struct OnboardingSwipeHint: View {
    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Text("swipe to use")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(Color.black.opacity(0.8))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .glassEffect(
                                .regular.tint(.white.opacity(0.18)),
                                in: .capsule
                            )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.72))
                            .frame(width: 39, height: 39)
                            .glassEffect(
                                .regular.tint(.white.opacity(0.22)),
                                in: .circle
                            )
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Text("swipe to use")
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
                        }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .frame(width: 39, height: 39)
                        .background(.ultraThinMaterial.opacity(0.9), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
                        }
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.clear)
                        .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .opacity(0.001)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.4)
                        .opacity(0.001)
                }
            }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 8)
    }
}

private struct CaptureExperienceView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ZStack {
            if let image = appModel.capturedImage {
                UploadTransitionView(image: image, status: appModel.analysisStatus)
                    .transition(.opacity)
            } else {
                CameraCaptureView(cameraService: appModel.cameraService)
                    .transition(.opacity)
            }
        }
        .background(FFTheme.background.ignoresSafeArea())
    }
}

private struct CameraCaptureView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var cameraService: CameraService
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var suppressNextTapCapture = false
    private let workspaceWidth: CGFloat = 308
    private let viewfinderHeight: CGFloat = 394
    private let previewCornerRadius: CGFloat = 28

    var body: some View {
        Group {
            if cameraService.authorizationStatus == .denied {
                CameraPermissionView(cameraService: cameraService)
            } else {
                ZStack {
                    FFTheme.background.ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer(minLength: 112)

                        cameraGuide
                            .frame(width: workspaceWidth)

                        Spacer()

                        if let errorMessage = appModel.errorMessage {
                            Text(errorMessage)
                                .font(.ffCaption)
                                .foregroundStyle(FFTheme.textPrimary.opacity(0.72))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(FFTheme.paperElevated.opacity(0.82), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
                                }
                                .padding(.bottom, 18)
                        }

                        captureButton
                            .padding(.bottom, 86)
                    }
                }
            }
        }
        .task {
            cameraService.requestAccessIfNeeded()
            if cameraService.authorizationStatus == .authorized {
                cameraService.configureSessionIfNeeded()
            }
        }
        .task(id: selectedPhotoItem) {
            await handleSelectedPhoto()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            cameraService.requestAccessIfNeeded()
            if cameraService.authorizationStatus == .authorized {
                cameraService.configureSessionIfNeeded()
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
    }

    private var cameraGuide: some View {
        VStack(spacing: 18) {
            ZStack {
                previewSurface
                    .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                            .stroke(Color.black.opacity(0.055), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.035), radius: 26, x: 0, y: 12)

                RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.035), lineWidth: 1)
            }
            .frame(width: workspaceWidth, height: viewfinderHeight)

            Text("Frame the contents of your fridge.")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(FFTheme.textSecondary.opacity(0.82))
        }
    }

    private var captureButton: some View {
        captureButtonFace
            .contentShape(Circle())
            .onTapGesture {
                guard !suppressNextTapCapture else {
                    suppressNextTapCapture = false
                    return
                }

                appModel.capture()
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                suppressNextTapCapture = true
                HapticManager.tap()
                isShowingPhotoPicker = true
            }
    }

    @ViewBuilder
    private var previewSurface: some View {
        if cameraService.authorizationStatus == .authorized, cameraService.isConfigured {
            CameraPreview(session: cameraService.session)
        } else {
            ZStack {
                FFTheme.paperElevated

                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(FFTheme.textPrimary.opacity(0.7))

                    Text("Preparing camera")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FFTheme.textSecondary.opacity(0.8))
                }
            }
        }
    }

    @ViewBuilder
    private var captureButtonFace: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 0) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(FFTheme.textPrimary.opacity(0.82))
                    .frame(width: 72, height: 72)
                    .glassEffect(
                        .regular.tint(.white.opacity(0.34)).interactive(),
                        in: .circle
                    )
            }
        } else {
            Image(systemName: "camera.aperture")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(FFTheme.textPrimary.opacity(0.8))
                .frame(width: 72, height: 72)
                .background(.ultraThinMaterial.opacity(0.92), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.05), radius: 22, x: 0, y: 10)
        }
    }

    private func handleSelectedPhoto() async {
        guard let selectedPhotoItem else { return }

        defer {
            self.selectedPhotoItem = nil
        }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                appModel.errorMessage = "The selected image could not be loaded."
                return
            }

            appModel.processCapture(image)
        } catch {
            appModel.errorMessage = "Unable to open the selected photo right now."
        }
    }
}

private struct CameraPermissionView: View {
    @ObservedObject var cameraService: CameraService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Spacer()

                Text("Allow camera access")
                    .font(.ffDisplayTitle)
                    .foregroundStyle(.white)

                Text("Point the camera at the inside of the fridge. The app only needs one photo to continue.")
                    .font(.ffBody)
                    .foregroundStyle(.white.opacity(0.72))

                Button("Request Access") {
                    cameraService.requestAccessIfNeeded()
                }
                .font(.ffBodyMedium)
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white, in: Capsule())

                if cameraService.authorizationStatus == .denied {
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.ffBodyMedium)
                    .foregroundStyle(.white.opacity(0.84))
                }

                Spacer()
            }
            .padding(.horizontal, FFSpacing.md)
        }
    }
}

private struct UploadTransitionView: View {
    let image: UIImage
    let status: String

    @State private var imageScale: CGFloat = 0.96
    @State private var thumbnailOffset: CGFloat = 18
    @State private var statusOffset: CGFloat = 20
    @State private var statusOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            FFTheme.background
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 0)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 248, height: 332)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 16)
                    .scaleEffect(imageScale)
                    .offset(y: thumbnailOffset)

                statusContent
                    .offset(y: statusOffset)
                    .opacity(statusOpacity)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                imageScale = 1
                thumbnailOffset = 0
            }
            withAnimation(.easeInOut(duration: 0.42).delay(0.08)) {
                statusOffset = 0
                statusOpacity = 1
            }
        }
    }

    private var statusContent: some View {
        VStack(spacing: 14) {
            Text(status)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FFTheme.textPrimary.opacity(0.88))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            IntelligenceGeneratingCapsule()
        }
    }
}

private struct IntelligenceGeneratingCapsule: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(FFTheme.textPrimary.opacity(0.82))

            Text("Generating")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FFTheme.textPrimary.opacity(0.86))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .intelligenceBackground(in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
        }
        .frame(width: 228, height: 48)
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }
}

private struct ResultsView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let presentation: PresentedRecipeSheet
    @State private var sharePayload: SharePayload?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                coverImage

                if let recipe = presentation.primaryRecipe {
                    VStack(spacing: 0) {
                        Text("Recipe")
                            .font(.custom("SnellRoundhand", size: 45))
                            .foregroundStyle(FFTheme.textPrimary)
                            .padding(.top, 14)
                            .padding(.bottom, 22)

                        Text(recipe.title)
                            .font(.system(size: 18, weight: .regular, design: .default))
                            .foregroundStyle(FFTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 324)
                            .padding(.horizontal, 20)

                        Text(recipe.subtitle)
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundStyle(FFTheme.textPrimary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 326)
                            .padding(.top, 21)
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(FFTheme.textPrimary)
                                        .frame(width: 18, alignment: .leading)

                                    Text(step)
                                        .font(.system(size: 13, weight: .regular, design: .default))
                                        .foregroundStyle(FFTheme.textPrimary.opacity(0.84))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: 326, alignment: .leading)
                        .padding(.top, 38)
                        .padding(.horizontal, 24)

                        recipeActionBar(recipe: recipe)
                            .padding(.top, 34)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 48)
                    }
                }
            }
        }
        .background(FFTheme.background.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(item: $sharePayload) { payload in
            ActivityView(items: payload.items)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let generatedImageData = presentation.primaryRecipe?.generatedImageData,
           let generatedImage = UIImage(data: generatedImageData) {
            Image(uiImage: generatedImage)
                .resizable()
                .scaledToFill()
                .frame(height: 377)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(FFTheme.background)
                        .frame(height: 1)
                }
        } else if let imageData = presentation.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 377)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(FFTheme.background)
                        .frame(height: 1)
                }
        } else {
            FFTheme.paperElevated
                .frame(height: 377)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func recipeActionBar(recipe: RecipeSuggestion) -> some View {
        HStack(spacing: 12) {
            actionButton(
                systemImage: "square.and.arrow.up",
                prominent: false
            ) {
                HapticManager.sheet()
                sharePayload = appModel.makeSharePayload(for: recipe)
            }

            actionButton(
                systemImage: appModel.isSaved(recipe) ? "checkmark" : "bookmark",
                prominent: !appModel.isSaved(recipe)
            ) {
                appModel.save(recipe)
            }
            .disabled(appModel.isSaved(recipe))
        }
    }

    @ViewBuilder
    private func actionButton(
        systemImage: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 0) {
                Button(action: action) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(prominent ? FFTheme.paperElevated : FFTheme.textPrimary.opacity(0.88))
                        .frame(width: 52, height: 52)
                        .glassEffect(
                            .regular
                                .tint(
                                    prominent
                                        ? FFTheme.textPrimary.opacity(0.88)
                                        : .white.opacity(0.55)
                                )
                                .interactive(),
                            in: .circle
                        )
                }
                .buttonStyle(.plain)
            }
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(prominent ? FFTheme.paperElevated : FFTheme.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(
                        prominent ? FFTheme.textPrimary : FFTheme.paperElevated,
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: prominent ? 0 : 0.8)
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct LeadRecipeView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let recipe: RecipeSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.lg) {
            HStack {
                Text("Lead dish")
                    .font(.ffCaption)
                    .foregroundStyle(FFTheme.textSecondary)

                Spacer()

                Text("\(recipe.timeMinutes) min")
                    .font(.ffCaption)
                    .foregroundStyle(FFTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(recipe.title)
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .foregroundStyle(FFTheme.textPrimary)

                Text(recipe.subtitle)
                    .font(.ffBody)
                    .foregroundStyle(FFTheme.textSecondary)
            }

            Rectangle()
                .fill(FFTheme.textPrimary)
                .frame(height: 1)
                .opacity(0.12)

            detailBlock(title: "Why this works", text: recipe.whyItWorks, emphasis: true)
            detailBlock(title: "Why it is healthy", text: recipe.whyHealthy)
            detailBlock(title: "Why it tastes good", text: recipe.whyDelicious)

            VStack(alignment: .leading, spacing: FFSpacing.xs) {
                Text("Method")
                    .font(.ffCaption)
                    .foregroundStyle(FFTheme.textSecondary)
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: FFSpacing.xs) {
                        Text("\(index + 1)")
                            .font(.ffCaption)
                            .foregroundStyle(FFTheme.textSecondary)
                            .frame(width: 18, alignment: .leading)
                        Text(step)
                            .font(.ffBody)
                            .foregroundStyle(FFTheme.textPrimary)
                    }
                }
            }

            detailBlock(title: "Final result", text: recipe.finalResultDescription)

            if !recipe.pantryAssumptions.isEmpty {
                detailBlock(title: "Pantry assumed", text: recipe.pantryAssumptions.joined(separator: ", "))
            }

            HStack {
                Button {
                    appModel.prepareShare(for: recipe)
                } label: {
                    Text("Share")
                        .font(.ffBodyMedium)
                        .foregroundStyle(FFTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Button {
                    appModel.save(recipe)
                } label: {
                    Text(appModel.isSaved(recipe) ? "Saved" : "Save")
                        .font(.ffBodyMedium)
                        .foregroundStyle(appModel.isSaved(recipe) ? FFTheme.textSecondary : FFTheme.paperElevated)
                        .padding(.horizontal, FFSpacing.sm)
                        .padding(.vertical, 10)
                        .background(appModel.isSaved(recipe) ? FFTheme.paper : FFTheme.textPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, FFSpacing.lg)
    }

    private func detailBlock(title: String, text: String, emphasis: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.ffCaption)
                .foregroundStyle(FFTheme.textSecondary)
            Text(text)
                .font(emphasis ? .system(size: 20, weight: .medium) : .ffBody)
                .foregroundStyle(FFTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isShowingProfileSettings = false
    @State private var hasPresentedInitialSetup = false
    private let profilePrototypeSize = CGSize(width: 402, height: 874)
    private let profilePlayerCanvasSize = CGSize(width: 420, height: 912)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                staticArtworkCanvas(
                    width: geometry.size.width,
                    viewportHeight: geometry.size.height
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(FFTheme.background)

                identityCardOverlay(
                    width: geometry.size.width,
                    viewportHeight: geometry.size.height,
                    topInset: geometry.safeAreaInsets.top
                )
            }
        }
        .background(FFTheme.background.ignoresSafeArea())
        .task(id: selectedAvatarItem) {
            await handleSelectedAvatar()
        }
        .sheet(isPresented: $isShowingProfileSettings) {
            ProfileSettingsSheet(
                selectedAvatarItem: $selectedAvatarItem,
                name: Binding(
                    get: { appModel.profileName },
                    set: { appModel.updateProfileName($0) }
                ),
                location: Binding(
                    get: { appModel.profileLocation },
                    set: { appModel.updateProfileLocation($0) }
                ),
                avatarData: appModel.profileAvatarData
            )
        }
        .task {
            guard !hasPresentedInitialSetup, appModel.needsInitialProfileSetup else { return }
            hasPresentedInitialSetup = true
            isShowingProfileSettings = true
        }
        .onChange(of: isShowingProfileSettings) { _, isPresented in
            guard isPresented else { return }
            HapticManager.sheet()
        }
    }

    private func staticArtworkCanvas(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let canvasHeight = viewportHeight

        return ZStack(alignment: .top) {
            FFTheme.background

            profileArtwork(
                name: "fish",
                width: 404,
                height: 166,
                centerX: 82,
                centerY: 392,
                in: width,
                height: canvasHeight
            )

            profileArtwork(
                name: "apple",
                width: 148,
                height: 206,
                centerX: 374,
                centerY: 460,
                in: width,
                height: canvasHeight
            )

            profileArtwork(
                name: "orange",
                width: 245,
                height: 279,
                centerX: 72,
                centerY: 738,
                in: width,
                height: canvasHeight
            )

            if !showcaseCards.isEmpty {
                MasterRecipeCollectionShowcase(
                    cards: showcaseCards,
                    canvasWidth: width,
                    onSelect: { item in
                        appModel.openSavedRecipe(item.savedRecipe)
                    }
                )
                .position(
                    x: width * 0.5,
                    y: scaledY(canvasHeight, 615)
                )
                .zIndex(2)
            }
        }
        .frame(width: width, height: canvasHeight)
        .clipped()
    }

    private var showcaseCards: [MasterRecipeFlipCardItem] {
        appModel.savedRecipes.enumerated().map { index, saved in
            MasterRecipeFlipCardItem(
                savedRecipe: saved,
                accent: showcaseAccent(for: index)
            )
        }
    }

    private func showcaseAccent(for index: Int) -> Color {
        switch index % 3 {
        case 0:
            FFTheme.paperElevated
        case 1:
            FFTheme.saffron.opacity(0.28)
        default:
            FFTheme.tomato.opacity(0.22)
        }
    }

    private func identityCardOverlay(width: CGFloat, viewportHeight: CGFloat, topInset: CGFloat) -> some View {
        let cardWidth = width * (375 / profilePlayerCanvasSize.width)
        let cardHeight = cardWidth * (234 / 375)

        return identityCard(width: width, height: viewportHeight)
            .frame(width: cardWidth, height: cardHeight)
            .padding(.top, max(topInset - 32, 0))
    }

    private func identityCard(width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = width * (375 / profilePlayerCanvasSize.width)
        let cardHeight = cardWidth * (234 / 375)
        let cardCornerRadius = scaledX(width, 42)

        return Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 0) {
                    identityCardContent(cardWidth: cardWidth, cardHeight: cardHeight)
                        .frame(width: cardWidth, height: cardHeight)
                        .glassEffect(
                            .regular.tint(.white.opacity(0.6)),
                            in: .rect(cornerRadius: cardCornerRadius)
                        )
                }
            } else {
                identityCardContent(cardWidth: cardWidth, cardHeight: cardHeight)
                    .frame(width: cardWidth, height: cardHeight)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.65), lineWidth: 0.8)
                    }
            }
        }
        .shadow(color: Color.black.opacity(0.035), radius: 22, x: 0, y: 10)
        .zIndex(3)
    }

    private func identityCardContent(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let avatarData = appModel.profileAvatarData
        let nameWidth = cardWidth * (246 / 375)
        let locationWidth = cardWidth * (132 / 375)

        return Group {
            ZStack {
                avatarView(size: cardWidth * (86 / 375), avatarData: avatarData)
                    .position(x: cardWidth * 0.5, y: cardHeight * (78 / 234))

                settingsButton(size: cardWidth * (28 / 375))
                    .position(x: cardWidth * (337 / 375), y: cardHeight * (34 / 234))

                Text(appModel.profileName)
                    .font(.system(size: cardWidth * (18 / 375), weight: .regular, design: .default).width(.expanded))
                    .foregroundStyle(
                        appModel.profileName == AppViewModel.defaultProfileName
                            ? FFTheme.textPrimary.opacity(0.42)
                            : FFTheme.textPrimary
                    )
                    .kerning(0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)
                    .frame(width: nameWidth, height: cardHeight * (24 / 234))
                    .position(x: cardWidth * 0.5, y: cardHeight * (163 / 234))

                Text(appModel.profileLocation)
                    .font(.system(size: cardWidth * (11 / 375), weight: .regular, design: .default).width(.expanded))
                    .foregroundStyle(
                        appModel.profileLocation == AppViewModel.defaultProfileLocation
                            ? FFTheme.textPrimary.opacity(0.34)
                            : FFTheme.textPrimary.opacity(0.72)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .frame(width: locationWidth, height: cardHeight * (13 / 234))
                    .position(x: cardWidth * 0.5, y: cardHeight * (186 / 234))
            }
            .frame(width: cardWidth, height: cardHeight)
        }
    }

    private func profileArtwork(
        name: String,
        width artworkWidth: CGFloat,
        height artworkHeight: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat,
        in viewWidth: CGFloat,
        height viewHeight: CGFloat
    ) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
                width: scaledX(viewWidth, artworkWidth),
                height: scaledY(viewHeight, artworkHeight)
            )
            .clipped()
            .position(
                x: scaledX(viewWidth, centerX),
                y: scaledY(viewHeight, centerY)
            )
            .allowsHitTesting(false)
            .zIndex(1)
    }

    private func scaledX(_ width: CGFloat, _ value: CGFloat) -> CGFloat {
        width * (value / profilePrototypeSize.width)
    }

    private func scaledY(_ height: CGFloat, _ value: CGFloat) -> CGFloat {
        height * (value / profilePrototypeSize.height)
    }

    private func avatarView(size: CGFloat, avatarData: Data?) -> some View {
        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
            Group {
                if let avatarData, let image = UIImage(data: avatarData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.72))

                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.32, weight: .medium))
                            .foregroundStyle(FFTheme.textSecondary.opacity(0.82))
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change profile photo")
    }

    private func settingsButton(size: CGFloat) -> some View {
        Button {
            HapticManager.sheet()
            isShowingProfileSettings = true
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(FFTheme.textSecondary.opacity(0.88))
                .frame(width: size + 10, height: size + 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile settings")
    }

    private func handleSelectedAvatar() async {
        guard let selectedAvatarItem else { return }

        defer {
            self.selectedAvatarItem = nil
        }

        do {
            guard let data = try await selectedAvatarItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }

            appModel.updateProfileAvatar(image)
        } catch {
            appModel.errorMessage = "Unable to update the profile image right now."
        }
    }
}

private struct CollectionCardItem {
    let title: String
    let image: UIImage?
    let accent: Color
}

private struct RecipeCollectionShowcase: View {
    @Binding var currentIndex: Int
    @Binding var dragOffset: CGFloat

    let cards: [CollectionCardItem]
    let canvasWidth: CGFloat

    private var cardWidth: CGFloat { canvasWidth * (345 / 402) }
    private var cardHeight: CGFloat { cardWidth * (207 / 345) }
    private let progressDistance: CGFloat = 150
    private let maxVisibleCards = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            collectionLabel

            ZStack {
                ForEach(stackIndices.reversed(), id: \.self) { index in
                    let queueIndex = index - currentIndex

                    RecipeCollectionCard(
                        item: cards[index],
                        width: cardWidth,
                        height: cardHeight,
                        frontVisible: true
                    )
                    .scaleEffect(scaleFactor(for: queueIndex))
                    .offset(y: stackYOffset(for: queueIndex))
                    .opacity(alphaFactor(for: queueIndex))
                    .zIndex(Double(maxVisibleCards - queueIndex))
                }

                if let previousIndex {
                    RecipeCollectionCard(
                        item: cards[previousIndex],
                        width: cardWidth,
                        height: cardHeight,
                        frontVisible: upwardFrontVisible
                    )
                    .rotation3DEffect(
                        .degrees(upwardRotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.5
                    )
                    .zIndex(Double(maxVisibleCards + 2))
                }

                if shouldShowFrontCard, let frontIndex = visibleIndices.first {
                    RecipeCollectionCard(
                        item: cards[frontIndex],
                        width: cardWidth,
                        height: cardHeight,
                        frontVisible: downwardFrontVisible
                    )
                    .rotation3DEffect(
                        .degrees(downwardRotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.5
                    )
                    .opacity(frontCardOpacity)
                    .zIndex(Double(maxVisibleCards + 1))
                }
            }
            .frame(width: cardWidth, height: cardHeight + 120)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .gesture(cardDragGesture)
        }
        .frame(width: cardWidth, alignment: .leading)
    }

    private var visibleIndices: [Int] {
        let upperBound = min(currentIndex + min(maxVisibleCards, cards.count), cards.count)
        guard currentIndex < upperBound else { return [] }
        return Array(currentIndex..<upperBound)
    }

    private var stackIndices: [Int] {
        let upperBound = min(currentIndex + min(maxVisibleCards, cards.count), cards.count)
        guard currentIndex < upperBound else { return [] }

        let startIndex: Int
        if dragOffset < 0, currentIndex > 0 {
            startIndex = currentIndex
        } else {
            startIndex = min(currentIndex + 1, upperBound)
        }

        guard startIndex < upperBound else { return [] }
        return Array(startIndex..<upperBound)
    }

    private var gestureProgress: CGFloat {
        max(min(dragOffset / progressDistance, 1), -1)
    }

    private var shouldShowFrontCard: Bool {
        !(dragOffset < 0 && currentIndex > 0)
    }

    private var previousIndex: Int? {
        guard dragOffset < 0, currentIndex > 0 else { return nil }
        return currentIndex - 1
    }

    private var downwardRotation: Double {
        guard dragOffset > 0, currentIndex < cards.count - 1 else { return 0 }
        return Double(-180 * gestureProgress)
    }

    private var upwardRotation: Double {
        guard dragOffset < 0, currentIndex > 0 else { return -180 }
        return Double(-180 * (gestureProgress + 1))
    }

    private var downwardFrontVisible: Bool {
        !(dragOffset > 0 && gestureProgress >= 0.5)
    }

    private var upwardFrontVisible: Bool {
        dragOffset < 0 && gestureProgress <= -0.5
    }

    private var frontCardOpacity: Double {
        guard dragOffset > 0, gestureProgress >= 0.9 else { return 1 }
        let fadeProgress = min(max((gestureProgress - 0.9) / 0.1, 0), 1)
        return 1 - Double(fadeProgress)
    }

    @ViewBuilder
    private var collectionLabel: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 0) {
                Text("RECIPES COLLECTION")
                    .font(.system(size: 12, weight: .medium, design: .default).width(.expanded))
                    .foregroundStyle(FFTheme.textPrimary.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .glassEffect(
                        .regular.tint(.white.opacity(0.54)),
                        in: .capsule
                    )
            }
        } else {
            Text("RECIPES COLLECTION")
                .font(.system(size: 12, weight: .medium, design: .default).width(.expanded))
                .foregroundStyle(FFTheme.textPrimary.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
                }
        }
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if value.translation.height > 0, currentIndex >= cards.count - 1 {
                    dragOffset = 0
                } else if value.translation.height < 0, currentIndex <= 0 {
                    dragOffset = 0
                } else {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { _ in
                let progress = gestureProgress

                withAnimation(.easeInOut(duration: 0.2)) {
                    if dragOffset > 0, progress >= 0.5, currentIndex < cards.count - 1 {
                        currentIndex += 1
                    } else if dragOffset < 0, progress <= -0.5, currentIndex > 0 {
                        currentIndex -= 1
                    }
                    dragOffset = 0
                }
            }
    }

    private func scaleFactor(for queueIndex: Int) -> CGFloat {
        if queueIndex < 1 { return 1 }

        let scale = linearValue(
            x1: 1,
            x2: 8,
            y1: 0.95,
            y2: 0.5,
            x: CGFloat(queueIndex)
        )

        return max(scale, 0.1)
    }

    private func stackYOffset(for queueIndex: Int) -> CGFloat {
        if queueIndex < 1 { return 0 }

        var sum: CGFloat = 0
        for index in 1...queueIndex {
            let offset = max(
                linearValue(
                    x1: 1,
                    x2: 8,
                    y1: 35,
                    y2: 15,
                    x: CGFloat(index)
                ),
                5
            )
            sum += offset
        }
        return sum
    }

    private func alphaFactor(for queueIndex: Int) -> Double {
        if queueIndex < 3 { return 1 }

        let alpha = linearValue(
            x1: 3,
            x2: 9,
            y1: 1,
            y2: 0.2,
            x: CGFloat(queueIndex)
        )

        return Double(min(max(alpha, 0.1), 1))
    }

    private func linearValue(x1: CGFloat, x2: CGFloat, y1: CGFloat, y2: CGFloat, x: CGFloat) -> CGFloat {
        if x == x1 { return y1 }
        if x == x2 { return y2 }

        let k = (y1 - y2) / (x1 - x2)
        let m = (x1 * y2 - x2 * y1) / (x1 - x2)
        return k * x + m
    }
}

private struct RecipeCollectionCard: View {
    let item: CollectionCardItem
    let width: CGFloat
    let height: CGFloat
    let frontVisible: Bool

    private var imageHeight: CGFloat { height * (145 / 207) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.98))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)

            VStack(spacing: 0) {
                cardImage
                    .frame(height: imageHeight)

                HStack {
                    Text(item.title)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(FFTheme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(height: height - imageHeight)
                .background(Color.white.opacity(0.96))
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .opacity(frontVisible ? 1 : 0)
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var cardImage: some View {
        if let image = item.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 28,
                        style: .continuous
                    )
                )
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        item.accent.opacity(0.95),
                        Color.white.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 10) {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 66, height: 66)
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 118, height: 14)
                    Capsule()
                        .fill(Color.white.opacity(0.56))
                        .frame(width: 78, height: 10)
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 28,
                    style: .continuous
                )
            )
        }
    }
}

private struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedAvatarItem: PhotosPickerItem?
    @Binding var name: String
    @Binding var location: String

    let avatarData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                            Group {
                                if let avatarData, let image = UIImage(data: avatarData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color(.secondarySystemFill))

                                        Image(systemName: "person.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(width: 58, height: 58)
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Photo")
                                .font(.body.weight(.medium))
                            Text("Choose from library")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Profile") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.characters)

                    TextField("Location", text: $location)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    GeminiAttributionCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct GeminiAttributionCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "atom")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(FFTheme.textPrimary.opacity(0.92))

            VStack(spacing: 10) {
                Text("Powered by Google Gemini")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(FFTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Visual scanning, analysis, and recipe generations are powered by Gemini.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FFTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 290)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
    }
}

private struct EmptyArchiveView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Your archive is empty.")
                .font(.ffBodyMedium)
                .foregroundStyle(FFTheme.textPrimary)

            Text("Save a strong dish after analysis and it will appear here as a tear-off recipe sheet.")
                .font(.ffBody)
                .foregroundStyle(FFTheme.textSecondary)
        }
        .padding(FFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FFTheme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct RecipeRollView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let recipes: [SavedRecipe]

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Saved as working sheets. Drag one up to cook without removing it from the archive.")
                .font(.ffBody)
                .foregroundStyle(FFTheme.textSecondary)
                .frame(maxWidth: 580, alignment: .leading)

            TabView {
                ForEach(recipes) { saved in
                    RecipeArchiveSheet(saved: saved)
                        .padding(.vertical, 8)
                        .padding(.trailing, 18)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 560)
        }
    }
}

private struct RecipeArchiveSheet: View {
    @EnvironmentObject private var appModel: AppViewModel
    let saved: SavedRecipe

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack(alignment: .top) {
                    Text(saved.savedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.ffCaption)
                        .foregroundStyle(FFTheme.textSecondary)

                    Spacer()

                    Text("Archive")
                        .font(.ffCaption)
                        .foregroundStyle(FFTheme.textSecondary)
                }

                Text(saved.recipe.title)
                    .font(.ffRecipeSheetTitle)
                    .foregroundStyle(FFTheme.textPrimary)

                Text(saved.recipe.subtitle)
                    .font(.ffBody)
                    .foregroundStyle(FFTheme.textSecondary)

                Rectangle()
                    .fill(FFTheme.paperLine.opacity(0.8))
                    .frame(height: 1)

                sheetSection(title: "Used", text: saved.recipe.usedIngredients.joined(separator: ", "))
                sheetSection(title: "Best for", text: saved.recipe.whyItWorks)
                sheetSection(title: "Method", text: saved.recipe.steps.prefix(2).joined(separator: "\n"))

                Spacer()

                HStack {
                    Label("\(saved.recipe.timeMinutes) min", systemImage: "clock")
                        .font(.ffCaption)
                        .foregroundStyle(FFTheme.textSecondary)

                    Spacer()

                    Button {
                        appModel.prepareShare(for: saved.recipe)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(FFTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(FFSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(FFTheme.paperElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(FFTheme.paperLine.opacity(0.8), lineWidth: 1)
            }
            .rotationEffect(.degrees(Double(dragOffset.width / 18)))
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if value.translation.width > 110 || value.translation.height < -110 {
                            appModel.openCookMode(for: saved.recipe)
                        }
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                            dragOffset = .zero
                        }
                    }
            )

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                Text("Tear into cook mode")
                    .font(.ffCaption)
            }
            .foregroundStyle(FFTheme.textSecondary)
            .padding(.trailing, FFSpacing.sm)
            .padding(.bottom, FFSpacing.sm)
        }
    }

    private func sheetSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.ffCaption)
                .foregroundStyle(FFTheme.textSecondary)

            Text(text)
                .font(.ffBody)
                .foregroundStyle(FFTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CookModeView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let recipe: RecipeSuggestion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FFSpacing.md) {
                    Text(recipe.title)
                        .font(.ffRecipeTitle)
                        .foregroundStyle(FFTheme.textPrimary)

                    Text(recipe.finalResultDescription)
                        .font(.ffBody)
                        .foregroundStyle(FFTheme.textSecondary)

                    FlexibleChipLayout(items: recipe.usedIngredients, accent: FFTheme.olive)

                    VStack(alignment: .leading, spacing: FFSpacing.sm) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: FFSpacing.sm) {
                                Text("\(index + 1)")
                                    .font(.ffBodyMedium)
                                    .foregroundStyle(FFTheme.textSecondary)
                                    .frame(width: 22, alignment: .leading)

                                Text(step)
                                    .font(.ffBody)
                                    .foregroundStyle(FFTheme.textPrimary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, FFSpacing.md)
                .padding(.top, FFSpacing.lg)
                .padding(.bottom, FFSpacing.xl)
            }
            .background(FFTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        appModel.dismissCookMode()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appModel.prepareShare(for: recipe)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}


private struct IngredientSummaryRow: View {
    let title: String
    let confidence: Double
    let tint: Color
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.ffBody)
                    .foregroundStyle(FFTheme.textPrimary)

                Spacer()

                Text(confidenceLabel)
                    .font(.ffCaption)
                    .foregroundStyle(FFTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.1), in: Capsule())
            }

            if let note {
                Text(note)
                    .font(.ffCaption)
                    .foregroundStyle(FFTheme.textSecondary)
            }
        }
        .padding(.horizontal, FFSpacing.md)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FFTheme.paperLine.opacity(0.5))
                .frame(height: 1)
                .padding(.leading, FFSpacing.md)
        }
    }

    private var confidenceLabel: String {
        "\(Int(confidence * 100))%"
    }
}

private struct FlexibleChipLayout: View {
    let items: [String]
    let accent: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.ffCaption)
                    .foregroundStyle(FFTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

struct RecipeShareCardView: View {
    let presentation: PresentedRecipeSheet

    var body: some View {
        VStack(spacing: 0) {
            shareCoverImage

            if let recipe = presentation.primaryRecipe {
                VStack(spacing: 0) {
                    Text("Recipe")
                        .font(.custom("SnellRoundhand", size: 96))
                        .foregroundStyle(FFTheme.textPrimary)
                        .padding(.top, 34)
                        .padding(.bottom, 42)

                    Text(recipe.title)
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(FFTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 760)
                        .padding(.horizontal, 60)

                    Text(recipe.subtitle)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(FFTheme.textPrimary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 780)
                        .padding(.top, 32)
                        .padding(.horizontal, 72)

                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 18) {
                                Text("\(index + 1).")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(FFTheme.textPrimary)
                                    .frame(width: 34, alignment: .leading)

                                Text(step)
                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundStyle(FFTheme.textPrimary.opacity(0.84))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: 820, alignment: .leading)
                    .padding(.top, 64)
                    .padding(.horizontal, 96)
                    .padding(.bottom, 88)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(FFTheme.background)
            }
        }
    }

    @ViewBuilder
    private var shareCoverImage: some View {
        if let generatedImageData = presentation.primaryRecipe?.generatedImageData,
           let generatedImage = UIImage(data: generatedImageData) {
            Image(uiImage: generatedImage)
                .resizable()
                .scaledToFill()
                .frame(height: 760)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(FFTheme.background)
                        .frame(height: 2)
                }
        } else if let imageData = presentation.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 760)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(FFTheme.background)
                        .frame(height: 2)
                }
        } else {
            FFTheme.paperElevated
                .frame(height: 760)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel(service: ServiceFactory.makeService()))
}
