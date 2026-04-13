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

    private let gold = DesignSystem.Colors.accent

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 20) {
                // Header (fix fixiert oben)
                HStack {
                    Text(title).font(DesignSystem.Typography.appFont(style: .title2)).fontWeight(.bold).foregroundColor(.primary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").font(DesignSystem.Typography.appFont(size: 24)).foregroundColor(.gray)
                    }
                }
                .padding(.top, 25)
                .padding(.horizontal, 25)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        // Circular progress
                        ZStack {
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 10)
                                .frame(width: 140, height: 140)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(gold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 4) {
                                Image(systemName: icon).font(DesignSystem.Typography.appFont(size: 28)).foregroundColor(gold)
                                Text("\(Int(progress * 100))%")
                                    .font(DesignSystem.Typography.appFont(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.top, 10)

                        VStack(spacing: 8) {
                            Text("\(current) / \(target) \(unit)")
                                .font(DesignSystem.Typography.appFont(style: .title3)).fontWeight(.bold).foregroundColor(.primary)
                            Text("Resets every Monday")
                                .font(DesignSystem.Typography.appFont(style: .caption)).foregroundColor(.gray)
                        }

                        // This week's tours
                        if !appState.weeklyTours.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("This Week").font(DesignSystem.Typography.appFont(style: .headline)).foregroundColor(.primary)
                                ForEach(appState.weeklyTours) { tour in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tour.summitName).font(DesignSystem.Typography.appFont(style: .subheadline)).fontWeight(.semibold).foregroundColor(.primary)
                                            Text(tour.date, style: .date).font(DesignSystem.Typography.appFont(style: .caption2)).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text("+\(tour.elevationGainMeters)m")
                                            .font(DesignSystem.Typography.appFont(style: .caption)).fontWeight(.bold).foregroundColor(gold)
                                    }
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 25)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}
