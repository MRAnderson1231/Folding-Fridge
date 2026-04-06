import SwiftUI
import UIKit

struct MasterRecipeFlipCardItem: Identifiable {
    let savedRecipe: SavedRecipe
    let accent: Color

    var id: UUID { savedRecipe.id }
    var title: String { savedRecipe.recipe.title }
    var image: UIImage? {
        guard let data = savedRecipe.recipe.generatedImageData ?? savedRecipe.imageData else { return nil }
        return UIImage(data: data)
    }
}

struct MasterRecipeCollectionShowcase: View {
    let cards: [MasterRecipeFlipCardItem]
    let canvasWidth: CGFloat
    let onSelect: (MasterRecipeFlipCardItem) -> Void

    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0

    private var cardWidth: CGFloat { canvasWidth * (207 / 402) }
    private var cardHeight: CGFloat { cardWidth * (266 / 207) }
    private var revealOffset: CGFloat { cardWidth * 1.03 }
    private var dragThreshold: CGFloat { cardWidth * 0.28 }
    private var leadingInset: CGFloat { (canvasWidth - canvasWidth * (375 / 420)) * 0.5 }
    private var baseCardOffset: CGFloat { -((canvasWidth - cardWidth) * 0.5) + leadingInset }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            recipesLabel

            ZStack {
                ForEach(cards.indices, id: \.self) { index in
                    let layout = cardLayout(for: index)

                    if layout.isVisible {
                        RecipeCollectionCard(
                            item: cards[index],
                            width: cardWidth,
                            height: cardHeight
                        )
                        .scaleEffect(layout.scale)
                        .rotation3DEffect(
                            .degrees(layout.rotation),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: layout.anchor,
                            perspective: 0.92
                        )
                        .offset(x: baseCardOffset + layout.xOffset, y: layout.yOffset)
                        .opacity(layout.opacity)
                        .zIndex(layout.zIndex)
                        .onTapGesture {
                            guard index == currentIndex, abs(dragOffset) < 8 else { return }
                            onSelect(cards[index])
                        }
                    }
                }
            }
            .frame(width: canvasWidth, height: cardHeight + 10)
            .contentShape(Rectangle())
            .gesture(cardDragGesture)
        }
        .onChange(of: cards.count) { _, newCount in
            guard newCount > 0 else {
                currentIndex = 0
                dragOffset = 0
                return
            }

            currentIndex = min(currentIndex, newCount - 1)
        }
    }

    @ViewBuilder
    private var recipesLabel: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 0) {
                    Text("RECIPES")
                        .font(.system(size: 12, weight: .medium, design: .default).width(.expanded))
                        .foregroundStyle(FFTheme.textPrimary.opacity(0.88))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.tint(.white.opacity(0.55)), in: .capsule)
                }
            } else {
                Text("RECIPES")
                    .font(.system(size: 12, weight: .medium, design: .default).width(.expanded))
                    .foregroundStyle(FFTheme.textPrimary.opacity(0.88))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
                    }
            }
        }
        .padding(.leading, leadingInset)
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if value.translation.width < 0, currentIndex >= cards.count - 1 {
                    dragOffset = 0
                } else if value.translation.width > 0, currentIndex <= 0 {
                    dragOffset = 0
                } else {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                let projected = value.translation.width + (value.predictedEndTranslation.width - value.translation.width) * 0.18

                var didChangeCard = false
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    if projected <= -dragThreshold, currentIndex < cards.count - 1 {
                        currentIndex += 1
                        didChangeCard = true
                    } else if projected >= dragThreshold, currentIndex > 0 {
                        currentIndex -= 1
                        didChangeCard = true
                    }
                    dragOffset = 0
                }

                if didChangeCard {
                    HapticManager.selection()
                }
            }
    }

    private func cardLayout(for index: Int) -> (isVisible: Bool, xOffset: CGFloat, yOffset: CGFloat, scale: CGFloat, rotation: Double, opacity: Double, zIndex: Double, anchor: UnitPoint) {
        let previousIndex = currentIndex - 1
        let nextIndex = currentIndex + 1
        let progress = max(min(dragOffset / cardWidth, 1), -1)
        let absProgress = abs(progress)

        if index == currentIndex {
            return (
                true,
                dragOffset,
                0,
                1 - absProgress * 0.035,
                Double(progress * -10),
                1,
                3,
                progress < 0 ? .trailing : .leading
            )
        }

        if index == nextIndex {
            let interactiveShift = dragOffset < 0 ? dragOffset * 0.22 : 0
            return (
                true,
                revealOffset + interactiveShift,
                8,
                dragOffset < 0 ? 0.91 + absProgress * 0.09 : 0.91,
                dragOffset < 0 ? Double((1 + progress) * 10) : 0,
                0.94,
                2,
                .leading
            )
        }

        if index == previousIndex {
            let interactiveShift = dragOffset > 0 ? dragOffset * 0.22 : 0
            return (
                true,
                -revealOffset + interactiveShift,
                8,
                dragOffset > 0 ? 0.91 + absProgress * 0.09 : 0.91,
                dragOffset > 0 ? Double((1 - progress) * -10) : 0,
                0.94,
                2,
                .trailing
            )
        }

        return (false, 0, 0, 1, 0, 0, 0, .center)
    }
}

private struct RecipeCollectionCard: View {
    let item: MasterRecipeFlipCardItem
    let width: CGFloat
    let height: CGFloat

    private var imageHeight: CGFloat { height * (176 / 266) }

    var body: some View {
        VStack(spacing: 0) {
            cardImage
                .frame(height: imageHeight)

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(FFTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.97))
        }
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.99))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.055), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var cardImage: some View {
        if let image = item.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 24,
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
                        .fill(Color.white.opacity(0.84))
                        .frame(width: 52, height: 52)
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 96, height: 12)
                    Capsule()
                        .fill(Color.white.opacity(0.56))
                        .frame(width: 64, height: 8)
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
            )
        }
    }
}
