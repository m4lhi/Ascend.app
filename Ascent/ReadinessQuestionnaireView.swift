import SwiftUI

// =========================================
// === DATEI: ReadinessQuestionnaireView.swift ===
// === Pro Mountaineer Subjective Input ===
// =========================================

struct ReadinessQuestionnaireView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var sleepQuality: Double = 3
    @State private var mentalMotivation: Double = 3
    @State private var muscleFatigue: Double = 3
    @State private var jointPain: Double = 0
    @State private var altitudeSymptoms: Bool = false
    
    private let accent = DesignSystem.Colors.accent
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.surfaceMuted.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        VStack(spacing: 20) {
                            QuestionSlider(
                                title: "Sleep Quality",
                                subtitle: "How restored do you feel?",
                                value: $sleepQuality,
                                icon: "bed.double.fill",
                                minLabel: "Exhausted",
                                maxLabel: "Restored"
                            )
                            
                            QuestionSlider(
                                title: "Mental Motivation",
                                subtitle: "Ready for technical precision?",
                                value: $mentalMotivation,
                                icon: "brain.headlight.fill",
                                minLabel: "Burnt out",
                                maxLabel: "Laser focused"
                            )
                            
                            QuestionSlider(
                                title: "Leg & Core Fatigue",
                                subtitle: "Current muscle soreness (DOMS)",
                                value: $muscleFatigue,
                                icon: "figure.run",
                                minLabel: "Heavy/Sore",
                                maxLabel: "Fresh/Light"
                            )
                            
                            QuestionSlider(
                                title: "Joint & Tendon Status",
                                subtitle: "Knees, ankles, or finger pulleys",
                                value: $jointPain,
                                icon: "bolt.heart.fill",
                                minLabel: "Pain-free",
                                maxLabel: "Acute Pain",
                                reverse: true
                            )
                            
                            ToggleSection(
                                title: "Altitude Symptoms?",
                                subtitle: "Headache, nausea, or dizziness",
                                isOn: $altitudeSymptoms,
                                icon: "mountain.2.fill"
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        Button(action: saveAndCalculate) {
                            Text("Calculate Manual Readiness")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        
                        Text("This score will supplement your wearable data for the next 24 hours.")
                            .font(.app(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.app(size: 40))
                .foregroundColor(accent)
                .padding(.top, 20)
            
            Text("Pro Readiness Check")
                .font(.app(size: 24, weight: .bold))
            
            Text("Wearables can't track everything. Tell us how you actually feel.")
                .font(.app(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.bottom, 10)
    }
    
    private func saveAndCalculate() {
        // Here we would push the subjective factors into the ReadinessManager
        // For now, we trigger a refresh in AppState
        appState.refreshReadiness()
        dismiss()
    }
}

struct QuestionSlider: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let icon: String
    let minLabel: String
    let maxLabel: String
    var reverse: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(DesignSystem.Colors.accent.opacity(0.1)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.app(size: 16)).foregroundColor(DesignSystem.Colors.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.app(size: 15, weight: .bold))
                    Text(subtitle).font(.app(size: 12)).foregroundColor(.secondary)
                }
            }
            
            Slider(value: $value, in: 1...5, step: 1)
                .tint(DesignSystem.Colors.accent)
            
            HStack {
                Text(minLabel).font(.app(size: 10)).foregroundColor(.secondary)
                Spacer()
                Text(maxLabel).font(.app(size: 10)).foregroundColor(.secondary)
            }
        }
        .sectionCard()
    }
}

struct ToggleSection: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(isOn ? Color.red.opacity(0.1) : Color.gray.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.app(size: 16)).foregroundColor(isOn ? .red : .gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.app(size: 15, weight: .bold))
                Text(subtitle).font(.app(size: 12)).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .sectionCard()
    }
}
