import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animating = false

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        let color: Color
        let x: CGFloat
        let targetY: CGFloat
        let rotation: Double
        let size: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.6)
                        .rotationEffect(.degrees(animating ? p.rotation + 360 : p.rotation))
                        .position(
                            x: p.x,
                            y: animating ? p.targetY : -20
                        )
                        .opacity(animating ? 0 : 1)
                }
            }
            .onAppear {
                let colors: [Color] = [.purple, .green, .orange, .cyan, .pink, .yellow, .mint]
                particles = (0..<40).map { _ in
                    ConfettiParticle(
                        color: colors.randomElement()!,
                        x: CGFloat.random(in: 0...geo.size.width),
                        targetY: geo.size.height + 20,
                        rotation: Double.random(in: 0...360),
                        size: CGFloat.random(in: 6...12)
                    )
                }
                withAnimation(.easeIn(duration: 2.0)) {
                    animating = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}
