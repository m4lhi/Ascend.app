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

    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)

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
                    Text(title).font(.system(.title2, design: .rounded)).fontWeight(.bold).foregroundColor(.primary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24, design: .rounded)).foregroundColor(.gray)
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
                                Image(systemName: icon).font(.system(size: 28, design: .rounded)).foregroundColor(gold)
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.top, 10)

                        VStack(spacing: 8) {
                            Text("\(current) / \(target) \(unit)")
                                .font(.system(.title3, design: .rounded)).fontWeight(.bold).foregroundColor(.primary)
                            Text("Resets every Monday")
                                .font(.system(.caption, design: .rounded)).foregroundColor(.gray)
                        }

                        // This week's tours
                        if !appState.weeklyTours.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("This Week").font(.system(.headline, design: .rounded)).foregroundColor(.primary)
                                ForEach(appState.weeklyTours) { tour in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tour.summitName).font(.system(.subheadline, design: .rounded)).fontWeight(.semibold).foregroundColor(.primary)
                                            Text(tour.date, style: .date).font(.system(.caption2, design: .rounded)).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text("+\(tour.elevationGainMeters)m")
                                            .font(.system(.caption, design: .rounded)).fontWeight(.bold).foregroundColor(gold)
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
