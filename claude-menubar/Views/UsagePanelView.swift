import SwiftUI

// MARK: - Root view

struct UsagePanelView: View {
    static let panelSize = CGSize(width: 318, height: 184)

    @ObservedObject var store: UsageStore
    let onQuit: () -> Void

    private var snapshot: UsageLimitSnapshot? { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 7)

            if let snap = snapshot, store.hasUsage {
                VStack(spacing: 6) {
                    UsageCard(
                        title: "현재 세션",
                        window: snap.currentSession,
                        now: store.now,
                        resetText: UsageFormatting.sessionResetText(
                            for: snap.currentSession.resetDate,
                            now: store.now
                        ),
                        accent: .neonGreen,
                    )
                    if let weekly = store.weeklyForDisplay {
                        UsageCard(
                            title: "모든 모델",
                            window: weekly,
                            now: store.now,
                            resetText: UsageFormatting.weeklyResetText(
                                for: weekly.resetDate,
                                now: store.now
                            ),
                            accent: .modelCyan,
                            onRefresh: store.refreshWeeklyDisplay
                        )
                    }
                }
            } else {
                emptyState
            }

            Spacer(minLength: 0)
            footer
                .padding(.top, 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .background(.regularMaterial)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.neonGreen)
                    .frame(width: 7, height: 7)
                Text("Claude")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            if let plan = snapshot?.planName {
                Text(plan)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claude Code 응답 후 표시됩니다")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Text("첫 번째 메시지를 보내면 실시간으로 연결됩니다.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text(UsageFormatting.compactUpdatedText(for: snapshot?.updatedDate))
                .font(.system(size: 9.5))
                .foregroundStyle(Color.primary.opacity(0.35))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button("종료") { onQuit() }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.45))
        }
    }
}

// MARK: - Card

private struct UsageCard: View {
    let title: String
    let window: UsageLimitSnapshot.UsageWindow
    let now: Date
    let resetText: String
    let accent: Color
    var onRefresh: (() -> Void)?

    private var pct: Double { window.effectivePercentage(now: now) ?? 0 }
    private var pctText: String {
        window.roundedPercentage(now: now).map { "\($0)%" } ?? "--%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Row 1: label + percentage
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                    .help("모든 모델 새로고침")
                }
                Spacer(minLength: 8)
                Text(pctText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
            .padding(.bottom, 4)

            // Row 2: progress bar
            ProgressStrip(value: pct / 100, tint: accent)
                .padding(.bottom, 4)

            // Row 3: compact reset detail
            Text(resetText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.48))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.052), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Progress strip

private struct ProgressStrip: View {
    let value: Double   // 0…1
    let tint: Color

    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.08))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .scaleEffect(x: min(1, max(0, value)), anchor: .leading)
            }
            .frame(height: 3.5)
    }
}

// MARK: - Color constants

private extension Color {
    static let neonGreen = Color(red: 0.22, green: 1.00, blue: 0.08)
    static let modelCyan = Color(red: 0.24, green: 0.82, blue: 0.94)
}

// MARK: - Preview

#Preview {
    UsagePanelView(store: UsageStore()) {}
}
