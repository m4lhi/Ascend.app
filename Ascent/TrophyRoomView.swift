import SwiftUI
import PhotosUI
import CoreLocation
import Combine

// =========================================
// === DATEI: TrophyRoomView.swift ===
// === Profil & Trophäen ===
// =========================================

// Helfer für den Standort
class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var detectedRegion: String?
    @Published var isFetching = false
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func fetchRegion() {
        isFetching = true
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            DispatchQueue.main.async { self.isFetching = false }
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                self.isFetching = false
                if let placemark = placemarks?.first {
                    let region = placemark.administrativeArea ?? placemark.country ?? ""
                    self.detectedRegion = region
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isFetching = false }
        print("❌ Standort-Fehler: \(error.localizedDescription)")
    }
}

// Hauptansicht für das Profil
struct TrophyRoomView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var showEditProfile = false
    @State private var progressAnimated = false
    @State private var showSettings = false
    @State private var showAscendRank = false

    
    private var requiredXP: Int { appState.xpNeededForNextLevel }
    private var xpProgress: Double {
        guard requiredXP > 0 else { return 0 }
        return Double(appState.currentLevelProgressXP) / Double(requiredXP)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    
                    HStack {
                        Spacer()
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill").font(.title2).foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 25).padding(.top, 15)
                    
                    // === 1. DER PROFIL HEADER ===
                    VStack(spacing: 15) {
                        ZStack(alignment: .bottomTrailing) {
                            if let imageData = appState.profileImage, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                            } else if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else if phase.error != nil {
                                        Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2).overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                                    } else {
                                        ProgressView().tint(.white)
                                    }
                                }
                                .frame(width: 100, height: 100).clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                            } else {
                                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2).frame(width: 100, height: 100)
                                    .overlay(Image(systemName: "person.fill").font(.largeTitle).foregroundColor(.gray))
                            }
                            
                            Button(action: { showEditProfile = true }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                    .padding(8).background(Color(red: 0.85, green: 0.65, blue: 0.13)).clipShape(Circle())
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            }
                        }
                        
                        VStack(spacing: 4) {
                            Text(appState.userName).font(.title2).fontWeight(.bold).foregroundColor(.white)
                            Text("@\(appState.userHandle)").font(.subheadline).foregroundColor(.gray)
                            
                            if !appState.userRegion.isEmpty && appState.userRegion != "Unknown" {
                                Text(appState.userRegion).font(.caption).foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13)).padding(.top, 2)
                            }
                        }
                        
                        if !appState.selectedSports.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Spacer().frame(width: 20)
                                    ForEach(appState.selectedSports, id: \.self) { sport in
                                        Text(sport).font(.caption).fontWeight(.semibold).foregroundColor(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.white.opacity(0.1)).clipShape(Capsule())
                                    }
                                    Spacer().frame(width: 20)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    // === 2. LEVEL & XP FORTSCHRITT ===
                    Button(action: { showAscendRank = true }) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Alpinist Rank").font(.headline).foregroundColor(.white)
                                Spacer()
                                if let profile = appState.ascendProfile {
                                    Text("\(profile.ascend_tier) \(profile.ascend_subtier)").font(.headline).foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                                } else {
                                    Text("Level \(appState.currentLevel)").font(.headline).foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                                }
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 8)
                                    Capsule().fill(Color(red: 0.85, green: 0.65, blue: 0.13))
                                        .frame(width: progressAnimated ? geo.size.width * xpProgress : 0, height: 8)
                                }
                            }.frame(height: 8)
                            
                            HStack {
                                if let profile = appState.ascendProfile {
                                    Text("\(Int(profile.ascend_xp)) XP").font(.caption).foregroundColor(.gray)
                                } else {
                                    Text("\(appState.currentLevelProgressXP) XP").font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(requiredXP) Total XP").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .padding(20).background(Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(20).padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)

                    
                    // === 3. ABZEICHEN ===
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Conquest Badges").font(.title3).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 20)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            ForEach(appState.badges) { badge in BadgeCard(badge: badge) }
                        }.padding(.horizontal, 20)
                    }
                    Spacer().frame(height: 120)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) { progressAnimated = true }
            }
        }
        .sheet(isPresented: $showEditProfile) { EditAccountView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showAscendRank) { AscendProgressView() }
    }
}


// Ansicht für ein einzelnes Abzeichen
struct BadgeCard: View {
    let badge: ConquestBadge
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(badge.isUnlocked ? (badge.isGold ? Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.15) : Color.white.opacity(0.1)) : Color.white.opacity(0.02))
                    .frame(height: 80)
                Image(systemName: badge.icon).font(.system(size: 30))
                    .foregroundColor(badge.isUnlocked ? (badge.isGold ? Color(red: 0.85, green: 0.65, blue: 0.13) : .white) : .gray.opacity(0.2))
            }
            Text(badge.title).font(.caption).fontWeight(.semibold)
                .foregroundColor(badge.isUnlocked ? .gray : .gray.opacity(0.3)).multilineTextAlignment(.center).lineLimit(2)
        }
    }
}

// =========================================
// === EDIT ACCOUNT VIEW ===
// =========================================
struct EditAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var locationFetcher = LocationFetcher()
    
    @State private var draftName: String = ""
    @State private var draftHandle: String = ""
    @State private var draftRegion: String = ""
    
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var draftImageData: Data? = nil
    @State private var draftSports: [String] = []
    
    @State private var showHandleErrorAlert = false

    let availableSports = ["Mountaineering", "Climbing", "Ski Touring", "Hiking", "Bouldering", "Ice Climbing", "Alpinism"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            if let data = draftImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
                            } else if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() }
                                    else { Circle().fill(Color.gray.opacity(0.2)) }
                                }.frame(width: 80, height: 80).clipShape(Circle())
                            } else {
                                Circle().fill(Color.gray.opacity(0.2)).frame(width: 80, height: 80).overlay(Image(systemName: "person.fill").foregroundColor(.gray).font(.title))
                            }
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text("Change Photo").font(.caption).fontWeight(.semibold).foregroundColor(.blue)
                            }
                        }
                        Spacer()
                    }.padding(.vertical, 5)
                }
                
                Section("Profile Info") {
                    TextField("Name", text: $draftName)
                    HStack {
                        Text("@").foregroundColor(.gray)
                        TextField("username", text: $draftHandle).autocapitalization(.none).onChange(of: draftHandle) { newValue in draftHandle = newValue.replacingOccurrences(of: "@", with: "") }
                    }
                    
                    HStack {
                        TextField("Region / State", text: $draftRegion)
                        Button(action: {
                            locationFetcher.fetchRegion()
                        }) {
                            if locationFetcher.isFetching {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill").foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section("Sports (Max 4)") {
                    ForEach(availableSports, id: \.self) { sport in
                        Button(action: {
                            if draftSports.contains(sport) { draftSports.removeAll { $0 == sport } }
                            else if draftSports.count < 4 { draftSports.append(sport) }
                        }) {
                            HStack {
                                Text(sport).foregroundColor(.primary)
                                Spacer()
                                if draftSports.contains(sport) { Image(systemName: "checkmark").foregroundColor(.blue).fontWeight(.bold) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            let isSuccess = await appState.updateProfileSettings(newName: draftName, newHandle: draftHandle, newRegion: draftRegion, newSports: draftSports)
                            
                            if isSuccess {
                                if let newData = draftImageData, newData != appState.profileImage {
                                    appState.profileImage = newData
                                    appState.uploadProfilePicture(data: newData)
                                }
                                await MainActor.run { dismiss() }
                            } else {
                                await MainActor.run { showHandleErrorAlert = true }
                            }
                        }
                    }.fontWeight(.bold)
                }
            }
            .onAppear {
                draftName = appState.userName
                draftHandle = appState.userHandle
                draftRegion = appState.userRegion == "Unknown" ? "" : appState.userRegion
                draftSports = appState.selectedSports
                draftImageData = appState.profileImage
            }
            .onChange(of: locationFetcher.detectedRegion) { newRegion in
                if let new = newRegion {
                    draftRegion = new
                }
            }
            .onChange(of: photoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        DispatchQueue.main.async { draftImageData = data }
                    }
                }
            }
            .alert("Username taken", isPresented: $showHandleErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text("This @handle is already in use by another Alpinist. Please choose a different one.") }
        }
        .preferredColorScheme(.dark)
    }
}
