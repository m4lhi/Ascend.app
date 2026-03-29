import SwiftUI

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

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea()

            VStack(spacing: 30) {
                HStack {
                    Text(title).font(.title2).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.gray)
                    }
                }

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(gold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Image(systemName: icon).font(.system(size: 28)).foregroundColor(gold)
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                VStack(spacing: 8) {
                    Text("\(current) / \(target) \(unit)")
                        .font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Text("Resets every Monday")
                        .font(.caption).foregroundColor(.gray)
                }

                // This week's tours
                if !appState.weeklyTours.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This Week").font(.headline).foregroundColor(.white)
                        ForEach(appState.weeklyTours) { tour in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tour.summitName).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                                    Text(tour.date, style: .date).font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                Text("+\(tour.elevationGainMeters)m")
                                    .font(.caption).fontWeight(.bold).foregroundColor(gold)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                        }
                    }
                }

                Spacer()
            }
            .padding(25)
        }
    }
}
