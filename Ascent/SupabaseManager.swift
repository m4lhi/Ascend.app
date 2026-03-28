import Foundation
import SwiftUI      // Verbindet unseren Code mit der Benutzeroberfläche
import Combine      // Wird zwingend für @Published und ObservableObject gebraucht
import Supabase     // Lädt das Supabase-Werkzeug für die Datenbank

// =========================================
// === SUPABASE CONNECTION MANAGER ===
// =========================================

// Initialize the Supabase client with your specific project details
// (Replace "YOUR_URL" and "YOUR_ANON_KEY" with your real keys from the Supabase dashboard!)
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qujkzrwrhrqejsqulohy.supabase.co")!,
    supabaseKey: "sb_publishable_tzrr2n1ElsAYIl7jAzWAiw_BT7DsRsv"
)

@MainActor
class MountainManager: ObservableObject {
    // This array will hold the mountains fetched from the database
    @Published var mountains: [Mountain] = []
    
    // Function to download the mountains from Supabase
    func fetchMountainsFromDatabase() async {
        do {
            // Asks Supabase to select all rows from the 'mountains' table
            // and decode them directly into our Mountain Swift struct!
            let fetchedMountains: [Mountain] = try await supabase
                .from("mountains")
                .select()
                .execute()
                .value
            
            // Updates the UI with the downloaded mountains
            self.mountains = fetchedMountains
            print("✅ Successfully loaded \(mountains.count) mountains from Supabase!")
            
        } catch {
            print("❌ Error fetching mountains from Supabase: \(error)")
        }
    }
}
