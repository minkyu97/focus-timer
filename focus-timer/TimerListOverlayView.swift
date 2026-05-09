import SwiftUI

struct TimerListOverlayView: View {
    @ObservedObject var store: TimerStore

    let accentColor: Color
    let onSelect: (StoredTimer) -> Void
    let onClose: () -> Void

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconCircleButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "Back",
                    size: 34,
                    action: onClose
                )

                Text("Timers")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button {
                    store.clearRecentTimers()
                } label: {
                    Text("Clear")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.hasRecentTimers ? accentColor : Color.secondary)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
                .disabled(!store.hasRecentTimers)
                .opacity(store.hasRecentTimers ? 1 : 0.45)
                .accessibilityLabel("Clear recent timers")
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 8)

            if store.sortedTimers.isEmpty {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("No recent timers")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Start a timer to add it here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.sortedTimers) { timer in
                            TimerCardView(
                                timer: timer,
                                accentColor: accentColor,
                                onSelect: {
                                    onSelect(timer)
                                },
                                onTogglePinned: {
                                    store.togglePinned(timer)
                                },
                                onRemove: {
                                    store.remove(timer)
                                }
                            )
                        }
                    }
                    .padding(14)
                    .padding(.bottom, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TimerCardView: View {
    let timer: StoredTimer
    let accentColor: Color
    let onSelect: () -> Void
    let onTogglePinned: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(FocusTimerFormatting.compactDuration(timer.durationSeconds))
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .layoutPriority(1)

            Spacer(minLength: 4)

            Button(action: onTogglePinned) {
                Image(systemName: timer.isPinned ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(timer.isPinned ? accentColor : Color.secondary)
                    .frame(width: 26, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(timer.isPinned ? "Unpin timer" : "Pin timer")

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove timer")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(minHeight: 72, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(timer.isPinned ? 0.18 : 0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(FocusTimerFormatting.spokenDuration(timer.durationSeconds)), \(timer.isPinned ? "pinned" : "recent")")
    }
}
