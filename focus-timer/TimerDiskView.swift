import SwiftUI

struct TimerDiskView: View {
    let remainingSeconds: Int
    let selectedSeconds: Int
    let accentColor: Color
    let isRunning: Bool
    let onDurationChange: (Int) -> Void

    private var progress: Double {
        Double(max(0, remainingSeconds)) / Double(FocusTimerClock.maxDurationSeconds)
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = diameter / 2

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.07))

                TimerWedgeShape(progress: progress)
                    .fill(accentColor)

                ForEach(0..<60, id: \.self) { minute in
                    Capsule()
                        .fill(markColor(for: minute))
                        .frame(
                            width: minute.isMultiple(of: 5) ? 2.5 : 1,
                            height: minute.isMultiple(of: 5) ? 13 : 7
                        )
                        .offset(y: -radius + 13)
                        .rotationEffect(.degrees(Double(minute) * 6))
                }

                Circle()
                    .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)

                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: diameter * 0.22, height: diameter * 0.22)
                    .shadow(color: .black.opacity(0.12), radius: 7, y: 2)

                Circle()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 7, height: 7)
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let duration = durationSeconds(for: value.location, in: proxy.size) else { return }
                        onDurationChange(duration)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Timer disk")
            .accessibilityValue(FocusTimerFormatting.spokenDuration(selectedSeconds))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func markColor(for minute: Int) -> Color {
        if minute.isMultiple(of: 5) {
            return Color.primary.opacity(0.36)
        }

        return Color.primary.opacity(0.18)
    }

    private func durationSeconds(for location: CGPoint, in size: CGSize) -> Int? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 16 else { return nil }

        var angle = atan2(dx, -dy)
        if angle < 0 {
            angle += 2 * .pi
        }

        var minutes = Int(ceil(angle / (2 * .pi) * 60))
        if minutes == 0 {
            minutes = 60
        }

        return FocusTimerClock.clampedDuration(minutes * 60)
    }
}

private struct TimerWedgeShape: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        if clampedProgress >= 0.999 {
            var path = Path()
            path.addEllipse(
                in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
            return path
        }

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + clampedProgress * 360),
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}
