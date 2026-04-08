import SwiftUI
import Combine

// =========================================
// === DATEI: AIChatGuideView.swift ===
// === KI Assistent / Mountain Guide ===
// =========================================

// MARK: - Models
struct AIChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - ViewModel (API Readiness)
@MainActor
class AIChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = [
        AIChatMessage(text: "Hello! I'm your Ascent Guide. How can I help you plan your next mountain adventure today?", isUser: false, timestamp: Date())
    ]
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    
    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = AIChatMessage(text: trimmed, isUser: true, timestamp: Date())
        messages.append(userMessage)
        inputText = ""
        isTyping = true
        
        Task {
            await sendMessageToBackend(query: trimmed)
        }
    }
    
    /// DUMMY FUNCTION: Hook your FastAPI / Supabase backend here.
    private func sendMessageToBackend(query: String) async {
        // Simulate network latency
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // TODO: Replace with real REST API call
        // let response = await api.askAscentGuide(payload: query)
        let responseText = "That's a great question about the mountains! Make sure to pack your Arc'teryx jacket and stay hydrated. (This is a mock response from the backend hook)."
        
        let botMessage = AIChatMessage(text: responseText, isUser: false, timestamp: Date())
        
        withAnimation {
            self.isTyping = false
            self.messages.append(botMessage)
        }
    }
}

// MARK: - Main Presentational View
struct AIChatGuideView: View {
    @StateObject private var viewModel = AIChatViewModel()
    @Environment(\.dismiss) var dismiss
    
    // Theming Colors
    private let accentColor = Color(red: 0.1, green: 0.5, blue: 0.95) // Ascent Blue
    private let botBgColor = Color(red: 0.92, green: 0.93, blue: 0.95) // Slate Grey
    
    var body: some View {
        NavigationView {
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
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isTyping) { isTyping in
                        if isTyping {
                            withAnimation { proxy.scrollTo("TYPING_INDICATOR", anchor: .bottom) }
                        }
                    }
                }
                
                Divider()
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("Ask the Ascent Guide...", text: $viewModel.inputText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                        .clipShape(Capsule())
                        .font(.system(size: 16, design: .rounded))
                        .submitLabel(.send)
                        .onSubmit {
                            viewModel.sendMessage()
                        }
                    
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : accentColor)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.ignoresSafeArea())
            }
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

// MARK: - Subcomponents

struct ChatMessageCell: View {
    let message: AIChatMessage
    let accentColor: Color
    let botBgColor: Color
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .clipShape(ChatBubbleShape(isUser: true))
            } else {
                BotAvatar()
                Text(message.text)
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
