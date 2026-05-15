import SwiftUI
import Combine

// =========================================
// === DATEI: ObjectiveDetailView.swift ===
// === Detail-Sheet für Weekly Objectives ===
// =========================================

struct ObjectiveDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let title: String
    let icon: String
    let current: Int
    let target: Int
    let unit: String

    @State private var appeared = false
    private let accent = DesignSystem.Colors.accent

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Animated hero icon
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.10))
                            .frame(width: 110, height: 110)
                        Circle()
                            .fill(accent.opacity(0.07))
                            .frame(width: 82, height: 82)
                        // Animated progress ring
                        Circle()
                            .stroke(Color.secondary.opacity(0.08), lineWidth: 6)
                            .frame(width: 110, height: 110)
                        Circle()
                            .trim(from: 0, to: appeared ? progress : 0)
                            .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 110, height: 110)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.1).delay(0.2), value: appeared)
                        Image(systemName: icon)
                            .font(.system(size: 34, weight: .black))
                            .foregroundColor(accent)
                    }
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.48, dampingFraction: 0.60).delay(0.04), value: appeared)
                    .padding(.top, 20)

                    // Title + numbers
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.app(size: 22, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("\(Int(progress * 100))%")
                            .font(.appMono(size: 42, weight: .black))
                            .foregroundColor(accent)
                            .contentTransition(.numericText())
                        Text("\(current) / \(target) \(unit)")
                            .font(.appMono(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)

                    // This week's tours
                    if !appState.weeklyTours.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("THIS WEEK")
                                .font(.appMono(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .tracking(1.4)
                                .padding(.horizontal, 4)
                            ForEach(appState.weeklyTours) { tour in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tour.summitName)
                                            .font(.app(size: 14, weight: .semibold))
                                        Text(tour.date, style: .date)
                                            .font(.app(size: 12))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                    }
                                    Spacer()
                                    Text("+\(tour.elevationGainMeters)m")
                                        .font(.appMono(size: 13, weight: .black))
                                        .foregroundColor(accent)
                                }
                                .padding(14)
                                .background(DesignSystem.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
        .background(.clear)
        .adaptiveSheetBackground()
        .onAppear { withAnimation { appeared = true } }
    }
}
