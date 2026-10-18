import SwiftUI

// Vendored from Livsy90/IntelligenceGlow and adapted for this project.
extension View {
    @MainActor
    func intelligenceBackground<S: InsettableShape>(
        in shape: S
    ) -> some View {
        background(
            shape.intelligenceStroke()
        )
    }

    @MainActor
    func intelligenceOverlay<S: InsettableShape>(
        in shape: S
    ) -> some View {
        overlay(
            shape.intelligenceStroke()
        )
    }
}

extension InsettableShape {
    @MainActor
    func intelligenceStroke(
        lineWidths: [CGFloat] = [6, 9, 11, 15],
        blurs: [CGFloat] = [0, 4, 12, 15],
        updateInterval: TimeInterval = 0.4,
        animationDurations: [TimeInterval] = [0.5, 0.6, 0.8, 1.0],
        gradientGenerator: @MainActor @Sendable @escaping () -> [Gradient.Stop] = { .intelligenceStyle }
    ) -> some View {
        IntelligenceStrokeView(
            shape: self,
            lineWidths: lineWidths,
            blurs: blurs,
            updateInterval: updateInterval,
            animationDurations: animationDurations,
            gradientGenerator: gradientGenerator
        )
        .allowsHitTesting(false)
    }
}

private struct IntelligenceStrokeView<S: InsettableShape>: View {
    let shape: S
    let lineWidths: [CGFloat]
    let blurs: [CGFloat]
    let updateInterval: TimeInterval
    let animationDurations: [TimeInterval]
    let gradientGenerator: @MainActor @Sendable () -> [Gradient.Stop]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stops: [Gradient.Stop] = .intelligenceStyle

    var body: some View {
        let layerCount = min(lineWidths.count, blurs.count, animationDurations.count)
        let gradient = AngularGradient(
            gradient: Gradient(stops: stops),
            center: .center
        )

        ZStack {
            ForEach(0..<layerCount, id: \.self) { index in
                shape
                    .strokeBorder(gradient, lineWidth: lineWidths[index])
                    .blur(radius: blurs[index])
                    .animation(
                        reduceMotion ? .linear(duration: 0) : .easeInOut(duration: animationDurations[index]),
                        value: stops
                    )
            }
        }
        .task(id: updateInterval) {
            while !Task.isCancelled {
                stops = gradientGenerator()
                try? await Task.sleep(for: .seconds(updateInterval))
            }
        }
    }
}

private extension Array where Element == Gradient.Stop {
    static var intelligenceStyle: [Gradient.Stop] {
        [
            Color(red: 188 / 255, green: 130 / 255, blue: 243 / 255),
            Color(red: 245 / 255, green: 185 / 255, blue: 234 / 255),
            Color(red: 141 / 255, green: 159 / 255, blue: 255 / 255),
            Color(red: 255 / 255, green: 103 / 255, blue: 120 / 255),
            Color(red: 255 / 255, green: 186 / 255, blue: 113 / 255),
            Color(red: 198 / 255, green: 134 / 255, blue: 255 / 255)
        ]
        .map { Gradient.Stop(color: $0, location: Double.random(in: 0...1)) }
        .sorted { $0.location < $1.location }
    }
}
