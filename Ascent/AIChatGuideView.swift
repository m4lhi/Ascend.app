import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: AIChatGuideView.swift ===
// === KI Assistent / Mountain Guide ===
// =========================================

// MARK: - Models
struct AIChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - ViewModel (API Readiness)
@MainActor
class AIChatViewModel: ObservableObject {
    static let shared = AIChatViewModel()
    
    @Published var messages: [AIChatMessage] = []
    
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var messagesLeftToday: Int = 30
    
    private let maxMessagesPerDay = 50
    private let lastMessageDateKey = "AIChatLastMessageDate"
    private let messageCountKey = "AIChatMessageCount"
    private let messagesStorageKey = "AIChatMessagesV2"
    
    // !!! WICHTIG: Hier deinen echten API Key eintragen !!!
    // (Oder lass ihn von Supabase / einem sicheren Backend laden)
    private let apiKey = "AIzaSyCOKhRRR6Y7rLL_FPKZtHPVV12uVIA_xqw"

    init() {
        loadUsageLimit()
        loadMessages()
    }
    
    func clearHistory() {
        messages = [AIChatMessage(text: "Hello! I'm your Ascent Guide. What's your next mission?", isUser: false, timestamp: Date())]
        saveMessages()
    }
    
    private func loadMessages() {
        if let data = UserDefaults.standard.data(forKey: messagesStorageKey),
           let saved = try? JSONDecoder().decode([AIChatMessage].self, from: data) {
            self.messages = saved
        }
        if self.messages.isEmpty {
            self.messages = [
                AIChatMessage(text: "Hello! I'm your Ascent Guide. What's your next mission?", isUser: false, timestamp: Date())
            ]
            saveMessages()
        }
    }
    
    private func saveMessages() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: messagesStorageKey)
        }
    }
    
    func loadUsageLimit() {
        let defaults = UserDefaults.standard
        let lastDate = defaults.object(forKey: lastMessageDateKey) as? Date ?? Date.distantPast
        
        if Calendar.current.isDateInToday(lastDate) {
            let used = defaults.integer(forKey: messageCountKey)
            messagesLeftToday = max(0, maxMessagesPerDay - used)
        } else {
            messagesLeftToday = maxMessagesPerDay
            defaults.set(0, forKey: messageCountKey)
        }
    }
    
    private func incrementUsage() {
        let defaults = UserDefaults.standard
        let lastDate = defaults.object(forKey: lastMessageDateKey) as? Date ?? Date.distantPast
        
        var used = 0
        if Calendar.current.isDateInToday(lastDate) {
            used = defaults.integer(forKey: messageCountKey)
        }
        
        used += 1
        defaults.set(Date(), forKey: lastMessageDateKey)
        defaults.set(used, forKey: messageCountKey)
        messagesLeftToday = max(0, maxMessagesPerDay - used)
    }
    
    func sendMessage(appState: AppState) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if messagesLeftToday <= 0 {
            let limitMessage = AIChatMessage(text: "You've reached your daily limit of \(maxMessagesPerDay) messages. Come back tomorrow!", isUser: false, timestamp: Date())
            messages.append(limitMessage)
            inputText = ""
            return
        }
        
        let userMessage = AIChatMessage(text: trimmed, isUser: true, timestamp: Date())
        messages.append(userMessage)
        saveMessages()
        inputText = ""
        isTyping = true
        incrementUsage()
        
        // Coach/Onboarding Daten auslesen
        var extendedContext = ""
        if let onbData = UserDefaults.standard.data(forKey: "coaching_onboarding_data"),
           let savedOnb = try? JSONDecoder().decode(OnboardingData.self, from: onbData) {
            extendedContext += """
            Physical & Fitness State:
            - Age: \(savedOnb.age), Height: \(savedOnb.heightCm)cm, Weight: \(savedOnb.weightKg)kg
            - Endurance: \(savedOnb.endurance.rawValue), VO2Max: \(savedOnb.vo2max > 0 ? String(savedOnb.vo2max) : "Unknown")
            - Training Volume: \(savedOnb.sessionsPerWeek) sessions/week (\(savedOnb.minutesPerSession) min/session)
            - Base Goal: \(savedOnb.goalName.isEmpty ? "Not set" : savedOnb.goalName) in \(savedOnb.desiredMonths) months
            - Experience: \(savedOnb.experience.map { $0.rawValue }.joined(separator: ", ")), Glacier Exp: \(savedOnb.hasGlacierExperience)
            
            """
        }
        
        if let planData = UserDefaults.standard.data(forKey: "coaching_plan_data"),
           let savedPlan = try? JSONDecoder().decode(CoachingPlan.self, from: planData) {
            extendedContext += """
            Current Tracking Roadmap & Plan:
            - Final Objective: \(savedPlan.goalName) (\(savedPlan.goalElevation)m, \(savedPlan.region.displayName))
            - Adjusted Safe Timeline: \(savedPlan.safeTimelineMonths) months
            - Recommended Gear: \(savedPlan.gearRecommendations.joined(separator: ", "))
            - Roadmap Stations (Progression):
            """
            for station in savedPlan.stations {
                let status = station.isCompleted ? "[DONE]" : "[TODO]"
                extendedContext += "\n  \(status) \(station.title) (\(station.phase.rawValue) Phase) - \(station.subtitle)"
            }
            extendedContext += "\n\n"
        }
        
        // Baue den Kontext aus dem Profil des Users zusammen
        let userContext = """
        User Profile:
        - Name: \(appState.userName)
        - Level: \(appState.currentLevel) (\(appState.ascendProfile?.ascend_tier ?? "Bronze"))
        - Completed Tours: \(appState.recentTours.filter { $0.isCurrentUser }.count)
        - Region: \(appState.userRegion)
        
        \(extendedContext)
        You are an elite expert mountain guide & AI Coach.
        RULES:
        1. SAFETY & LIABILITY: Never guarantee safety. Always remind the user to consult local certified mountain guides and official avalanche/weather forecasts before any critical tour. You are an AI assistant, not a physically present guide.
        2. FOCUS: Only answer questions related to alpinism, hiking, fitness, mountains, and gear. If the user asks about programming, politics, cooking, or other unrelated topics, politely decline and steer the conversation back to the mountains.
        3. STYLE: Keep answers concise, highly specific, and actionable. Reference their fitness, roadmap, and gear if relevant. Keep markdown formatting clean and minimal.
        4. COACHING AWARENESS: You are fully aware of their generated roadmap above. If they ask "what should I do next?" or "what gear do I need?", look at their [TODO] stations, their overall objective, and their gear list.
        5. MOUNTAIN DEEP LINKING: Whenever you recommend or mention a specific real-world mountain to climb or explore (e.g. Zugspitze, Matterhorn, Mont Blanc), format it exactly as a Markdown link using the custom scheme 'ascent://mountain/NAME'. CRITICAL: You MUST replace any spaces in the URL part with '%20'.
        Good Example: You should explore the [Mont Blanc](ascent://mountain/Mont%20Blanc) to prepare.
        Make it very naturally woven into the sentence.
        """
        
        let history = messages // Capture the chat history
        Task {
            await sendMessageToBackend(history: history, context: userContext)
        }
    }
    
    // Echter API Call an ein LLM (z.B. OpenAI / Gemini)
    private func sendMessageToBackend(history: [AIChatMessage], context: String) async {
        // Falls du noch keinen Key hast, simulieren wir die Antwort vorerst:
        guard apiKey != "DEIN_API_KEY_HIER" && !apiKey.isEmpty else {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let responseText = "I see your profile data! As a level \(context.contains("Level: 10") ? "10" : "x") alpinist, you should pack light."
            let botMessage = AIChatMessage(text: responseText, isUser: false, timestamp: Date())
            withAnimation {
                self.isTyping = false
                self.messages.append(botMessage)
                self.saveMessages()
            }
            return
        }

        // Gemini API Configuration
        let safeKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(safeKey)"
        guard let url = URL(string: urlString) else {
            showError("Invalid API URL. Check your API key for illegal characters.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var geminiContents: [[String: Any]] = []
        for msg in history {
            // Skip the initial welcome message as Gemini expects the conversation to start cleanly
            if !msg.isUser && msg.text.starts(with: "Hello! I'm your") { continue }
            
            geminiContents.append([
                "role": msg.isUser ? "user" : "model",
                "parts": [ ["text": msg.text] ]
            ])
        }
        
        let body: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": context]
                ]
            ],
            "contents": geminiContents
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("API returned error code: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Error details: \(errorString)")
                }
                throw URLError(.badServerResponse)
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let contentObj = candidates.first?["content"] as? [String: Any],
               let parts = contentObj["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                
                let botMessage = AIChatMessage(text: text.trimmingCharacters(in: .whitespacesAndNewlines), isUser: false, timestamp: Date())
                withAnimation {
                    self.isTyping = false
                    self.messages.append(botMessage)
                }
            } else {
                throw URLError(.badServerResponse)
            }
        } catch {
            print("Chat API Error: \(error)")
            showError("Sorry, the satellite connection to my brain is currently down. Try again later!")
        }
    }
    
    private func showError(_ text: String) {
        let errorMessage = AIChatMessage(text: text, isUser: false, timestamp: Date())
        withAnimation {
            self.isTyping = false
            self.messages.append(errorMessage)
            self.saveMessages()
        }
    }
}

// MARK: - Main Presentational View
struct AIChatGuideView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AIChatViewModel.shared
    @Environment(\.dismiss) var dismiss
    
    var isEmbedded: Bool = false
    
    // Theming Colors
    private let accentColor = DesignSystem.Colors.accent // Ascent Blue
    private let botBgColor = Color(red: 0.92, green: 0.93, blue: 0.95) // Slate Grey
    
    var body: some View {
        Group {
            if isEmbedded {
                chatContent
            } else {
                NavigationView {
                    chatContent
                        .navigationTitle("Ascent Guide")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") {
                                    dismiss()
                                }
                                .font(.system(.body, design: .rounded).bold())
                                .foregroundColor(accentColor)
                            }
                        }
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "ascent", url.host == "mountain", let name = url.pathComponents.last?.removingPercentEncoding { // e.g. ascent://mountain/Zugspitze
                Task {
                    if let mt: Mountain = try? await supabase.from("mountains")
                        .select("*, routes:mountain_routes(*)")
                        .eq("name", value: name)
                        .limit(1)
                        .single()
                        .execute().value {
                        DispatchQueue.main.async {
                            dismiss()
                            appState.exploreSelectedMountain = mt
                        }
                    }
                }
                return .handled
            }
            return .systemAction
        })
    }
    
    private var chatContent: some View {
        VStack(spacing: 0) {
            
            // Chat Message List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            ChatMessageCell(message: message, accentColor: accentColor, botBgColor: botBgColor)
                                .id(message.id)
                        }
                        
                        if viewModel.isTyping {
                            HStack {
                                BotAvatar()
                                TypingIndicatorView()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(botBgColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .id("TYPING_INDICATOR")
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color.white.ignoresSafeArea())
                .onChange(of: viewModel.messages.count) {
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isTyping) { _, isTyping in
                    if isTyping {
                        withAnimation { proxy.scrollTo("TYPING_INDICATOR", anchor: .bottom) }
                    }
                }
            }
            
            Divider()
            
            // Input Area
            VStack(spacing: 8) {
                Text("\(viewModel.messagesLeftToday) daily messages remaining")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.messagesLeftToday > 0 ? .gray : .red)
                
                HStack(spacing: 12) {
                    TextField("Ask the Ascent Guide...", text: $viewModel.inputText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                        .clipShape(Capsule())
                        .font(.system(size: 16, design: .rounded))
                        .submitLabel(.send)
                        .onSubmit {
                            viewModel.sendMessage(appState: appState)
                        }
                        .disabled(viewModel.messagesLeftToday <= 0)
                    
                    Button(action: {
                        viewModel.sendMessage(appState: appState)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.messagesLeftToday <= 0)
                                    ? Color.gray.opacity(0.5) : accentColor
                            )
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.messagesLeftToday <= 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.ignoresSafeArea())
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AskAIAbooutStation"))) { notif in
            if let title = notif.object as? String {
                viewModel.inputText = "Can you give me a detailed workout/training plan for the '\(title)' stage in my roadmap?"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if viewModel.messagesLeftToday > 0 {
                        viewModel.sendMessage(appState: appState)
                    }
                }
            }
        }
    }
}

// MARK: - Subcomponents

struct ChatMessageCell: View {
    let message: AIChatMessage
    let accentColor: Color
    let botBgColor: Color
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 40)
                Text(.init(message.text))
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .clipShape(ChatBubbleShape(isUser: true))
            } else {
                BotAvatar()
                Text(.init(message.text))
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(botBgColor)
                    .clipShape(ChatBubbleShape(isUser: false))
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct BotAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 32, height: 32)
            Image(systemName: "leaf.fill") // Nature/Outdoor theme icon
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}

struct ChatBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                isUser ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        return Path(path.cgPath)
    }
}

struct TypingIndicatorView: View {
    @State private var offset: CGFloat = 0
    let dotSize: CGFloat = 6
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: offset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(0.15 * Double(index)),
                        value: offset
                    )
            }
        }
        .onAppear {
            offset = -5
        }
    }
}
