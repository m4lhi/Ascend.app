# Ascent — AI-Powered Mountaineering Platform

> A native iOS app that transforms alpine sports into a data-driven, gamified experience — combining real-time GPS tracking, Apple Health analytics, AI coaching, avalanche safety, and a competitive progression system.

**37,000+ lines of Swift** | **80+ source files** | **Supabase Backend** | **Deno Edge Functions**

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Technical Architecture](#technical-architecture)
- [Technology Stack](#technology-stack)
- [Module Breakdown](#module-breakdown)
- [Backend & Infrastructure](#backend--infrastructure)
- [AI Integration](#ai-integration)
- [Design System](#design-system)
- [Skills & Technologies Applied](#skills--technologies-applied)

---

## Overview

Ascent is a full-featured mountaineering companion app built natively for iOS with SwiftUI. It goes beyond simple GPS tracking by integrating real-time biometric data from Apple Health, AI-powered coaching via Claude, European avalanche bulletins, live weather overlays, and a sophisticated XP/ranking system — all wrapped in a premium dark OLED design with custom typography and 3D visual effects.

The app was designed and developed as a solo full-stack project, covering everything from database schema design and serverless backend logic to complex GPS algorithms, health data analysis pipelines, and polished UI/UX with custom animations.

---

## Key Features

### Real-Time GPS Tracking & Navigation
- Live GPS recording with CoreLocation (best-for-navigation accuracy) and CoreMotion barometric altimeter
- Dual-sensor elevation tracking with 5-point sliding window noise filter and 1.5m outlier threshold
- Intelligent auto-pause detection using GPS drift standard deviation analysis and speed thresholds
- Turn-by-turn voice navigation with bearing-based directional cues (atan2 trigonometry)
- Route interception algorithm for predefined mountain routes with polyline segment rendering
- GPX 1.1 and KML import/export with XML parsing and security-scoped file access

### Apple Health Integration
- Deep HealthKit integration: heart rate, HRV, VO2max, SpO2, resting HR, sleep stages, respiratory rate
- Live heart rate streaming via HKAnchoredObjectQuery during active tours
- 30/90-day fitness trend analysis with multi-metric trend detection (improving/stable/declining)
- Sport activity breakdown by workout type with session count, duration, and elevation statistics
- Altitude exposure history tracking (days above 2000m, 3000m, 4000m)
- Sleep quality analysis with stage classification (deep, REM, core, awake)
- Recovery quality indicators for training load management

### Summit Readiness Engine
- Composite readiness score (0–100) with weighted subsystem analysis:
  - Physiological score (40%): HRV, resting HR, SpO2, blood oxygen trends
  - Workload score (30%): Acute-to-Chronic Workload Ratio (ACWR)
  - Altitude score (20%): Acclimatization based on recent altitude exposure
  - Environment score (10%): Target mountain weather conditions
- Personalized recommendations based on combined physiological and environmental data

### AI Coaching (Claude Integration)
- Personalized multi-phase training plans generated via Claude API
- Structured onboarding collecting fitness metrics (height, weight, VO2max, experience level)
- Phase-based progression: Foundation → Build → Peak Prep → Summit Push
- Station-based roadmap with 7 activity types (hike, technique, strength, endurance, acclimatization, glacier, summit)
- Gear recommendations and personalized reasoning for each training station
- Interactive chat interface for ongoing coaching dialogue

### Alpine Safety
- European Avalanche Warning Service (EAWS) integration with real-time bulletins
- Swiss SLF (WSL Institute) integration with automatic region detection via bounding box
- Danger level display (1–5 scale) with elevation-dependent ratings and problem types
- Wind chill calculation (JAG/TI model) and freezing level estimation (lapse rate algorithm)
- Weather tile overlays (OpenWeatherMap, RainViewer radar) with hourly forecast scrubbing
- Emergency SOS system with contact management and real-time location sharing via Supabase
- Live tracking sessions with GPS coordinates broadcast to backend

### Gamification & Progression
- XP system with logarithmic base formula: `XP = 8 × log₁₀(distance + 1) × (1 + elevation/1200) × (1 + difficulty/6)`
- Activity-specific multipliers (ski touring 2x elevation, climbing 1.6x + 20 XP, prestige peaks 2.5–5.0x)
- Streak system with daily consistency bonus (up to +50% at max streak)
- Weekly activity diversity multiplier (+10% per unique activity type)
- Anti-exploit measures: daily XP cap (10,000), distance minimum (1km), elevation minimum (50m)
- 5-tier ranking: Bronze → Silver → Gold → Platinum → Obsidian (with subtiers I–III)
- Obsidian tier gating: requires 25+ prestige peaks and 3+ weekly activity types
- Level-up curve: `XP_needed(level) = 50 × level^1.8`
- Achievement system with 3D trophy visualization
- Leaderboards (global, regional, friends)

### Cinematic Route Replay
- 3D satellite terrain replay using MapLibre GL JS with DEM elevation data
- Precomputed cumulative distances and elevation gains for smooth scrubbing
- 60fps animation loop with bearing interpolation and exponential camera easing
- Speed multiplier controls (0.5x–4x) with pause/resume state management
- Statistics overlay: elevation, distance, grade, elapsed time updated per-frame
- JavaScript ↔ Swift bidirectional bridge via WKWebView message handlers

### Live Activities & Dynamic Island
- iOS 16.2+ ActivityKit integration for lock screen and Dynamic Island display
- Real-time metrics: duration, distance, remaining distance, average speed, pause state
- Intelligent update throttling: 30-second minimum interval, 100m distance threshold, or state change
- Prevents APNS rate limiting that would cause Apple to kill the Live Activity

### Interactive Elevation Profiles
- Swift Charts (AreaMark, LineMark, RuleMark, PointMark) with gradient fills
- Gradient-based segment coloring: flat (<8%), moderate (8–15%), steep (15–25%), very steep (>25%), descent (<-5%)
- Pinch-to-zoom (1–5x) with horizontal scroll paging
- Interactive scrubber with coordinate selection and map sync
- Altitude smoothing with 5-point sliding window filter

### Offline Capabilities
- Route data caching for offline mountain access
- Local persistence via UserDefaults and Codable serialization
- Offline-capable mountain database with route polylines

### Maps & Tile Layers
- Mapbox Maps SDK with satellite, terrain DEM (1.5x exaggeration), and custom tile overlays
- Dynamic tile overlay system: topographic, satellite, slope angle layers with configurable opacity
- Google Polyline Algorithm encoder/decoder for compact route storage
- Alpine weather map with OpenWeatherMap tiles, RainViewer radar, and wind particle visualization
- Mountain annotation system with custom markers and clustering

---

## Technical Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SwiftUI Frontend                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐ │
│  │ Basecamp │ │ Explore  │ │Analytics │ │Live Record │ │
│  │Dashboard │ │  & Map   │ │& Health  │ │  & Track   │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────┬──────┘ │
│       │             │            │              │        │
│  ┌────┴─────────────┴────────────┴──────────────┴────┐  │
│  │              AppState (Observable Hub)             │  │
│  │         Centralized Reactive State Management     │  │
│  └───────┬──────────┬──────────┬──────────┬──────────┘  │
│          │          │          │          │              │
│  ┌───────┴──┐ ┌─────┴────┐ ┌──┴───────┐ ┌┴───────────┐ │
│  │HealthKit │ │CoreLocat.│ │  Mapbox  │ │ ActivityKit│ │
│  │  Bridge  │ │  + Core  │ │  Maps +  │ │   + Live   │ │
│  │  + HRV   │ │  Motion  │ │ MapLibre │ │ Activities │ │
│  └──────────┘ └──────────┘ └──────────┘ └────────────┘ │
└──────────────────────────┬──────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │  Supabase   │
                    │  Backend    │
                    ├─────────────┤
                    │ PostgreSQL  │
                    │    + RLS    │
                    ├─────────────┤
                    │ Deno Edge   │
                    │ Functions   │
                    ├─────────────┤
                    │    Auth     │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │ External    │
                    │ APIs        │
                    ├─────────────┤
                    │ Claude AI   │
                    │ EAWS / SLF  │
                    │ OpenMeteo   │
                    │ RainViewer  │
                    │ OWM Tiles   │
                    └─────────────┘
```

**Design Patterns Used:**
- **MVVM** with SwiftUI's `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
- **Observable Hub** — centralized `AppState` (1,400+ LOC) as single source of truth
- **Singleton Services** — `EmergencyManager.shared`, `AvalancheService.shared`, `ReadinessManager.shared`
- **Coordinator** — `WKNavigationDelegate` + `WKScriptMessageHandler` for JS bridge
- **Strategy** — `MapLayerType` enum determines tile URL template and opacity
- **Factory** — tile overlay creation, GPX/KML generation, navigation instruction building
- **State Machine** — navigation engine (instruction index advancement), auto-pause detection, Live Activity lifecycle
- **Adapter** — `UIViewRepresentable` wrappers for Mapbox, MKMapView, WKWebView, UIDocumentPicker

---

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Language** | Swift 5.9+, TypeScript (Deno) |
| **UI Framework** | SwiftUI, Swift Charts, UIKit (via UIViewRepresentable) |
| **Maps** | Mapbox Maps SDK, MapKit, MapLibre GL JS |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| **Serverless** | Deno Edge Functions (Supabase Functions) |
| **Health** | HealthKit (HKAnchoredObjectQuery, HKStatisticsQuery, HKSampleQuery) |
| **Location** | CoreLocation (CLLocationManager), CoreMotion (CMAltimeter) |
| **AI** | Claude API (Anthropic) for coaching and plan generation |
| **Live Activities** | ActivityKit (iOS 16.2+) |
| **Weather APIs** | OpenMeteo, OpenWeatherMap, RainViewer |
| **Safety APIs** | EAWS (European Avalanche Warning), SLF (Swiss) |
| **Web Rendering** | WKWebView with MapLibre GL JS for 3D terrain replay |
| **Voice** | AVSpeechSynthesizer for turn-by-turn navigation |
| **Haptics** | CoreHaptics for tactile feedback |
| **Data Formats** | GPX 1.1, KML, Google Polyline Algorithm, JSON, XML |
| **Typography** | Custom fonts (CabinetGrotesk-Bold, Satoshi-Regular) |
| **Auth** | Supabase Auth with JWT |
| **Database** | PostgreSQL with Row Level Security (RLS) policies |

---

## Module Breakdown

| Module | Files | LOC | Description |
|--------|-------|-----|-------------|
| **GPS & Tracking** | LiveRecordView, NavigationManager, GPXImporter/Exporter, PolylineUtility | ~3,000 | Real-time GPS recording, auto-pause, voice navigation, route import/export |
| **Maps & Visualization** | AlpineWeatherMapView, MapTileOverlayHelper, ElevationProfileView, RouteReplayView | ~2,300 | Weather overlays, tile layers, elevation charts, 3D cinematic replay |
| **Health & Fitness** | HealthKitBridge, HealthDataProvider, HealthAnalysisEngine, ReadinessManager, LiveHeartRateMonitor | ~2,500 | Apple Health integration, trend analysis, readiness scoring, live HR |
| **AI Coaching** | AICoachingGateway, AIChatGuideView, CoachingTheme | ~2,000 | Claude-powered training plans, interactive chat, themed map visualization |
| **Gamification** | PrestigeSystem, AchievementData, Achievement3DView, ArenaView, TrophyRoomView | ~2,500 | XP system, ranks, achievements, leaderboards, 3D trophy room |
| **Safety** | AvalancheService, EmergencyManager, WeatherManager, OpenMeteoService | ~1,500 | Avalanche bulletins, SOS, live tracking, weather forecasting |
| **Social** | PublicProfileView, CollectionsManager, Basecamp (feed) | ~2,500 | User profiles, peak collections, activity feed, fist bumps |
| **Core & State** | AppState, ContentView, AscentApp, DesignSystem | ~2,400 | App architecture, navigation, reactive state, design tokens |
| **Widgets** | AscentWidget, AscentWidgetLiveActivity, MountaineeringAttributes | ~400 | Home screen widgets, Dynamic Island, lock screen Live Activities |
| **UI Components** | Various views, sheets, cards | ~18,000 | Dashboard, settings, onboarding, detail views, animations |

---

## Backend & Infrastructure

### PostgreSQL Schema (Supabase)
- **ascend_profiles**: XP, level, tier/subtier, streak tracking, weekly activity diversity
- **mountain_routes**: Route polylines with start coordinates, linked to mountain database
- **profiles**: User identity with specialties, hobbies, Instagram handle, disciplines
- **tours**: Activity log with route polylines for social feed rendering
- **hobbies**: Community-contributed hobby dictionary with normalized deduplication
- **collections / collection_members**: Peak collection system for group challenges
- **route_saves**: Persistent route bookmarks

### Row Level Security (RLS)
All tables enforce PostgreSQL RLS policies — users can only read/write their own data. Public data (profiles, hobbies, routes) has separate read-only policies.

### Edge Function: XP Calculation Engine
Server-side TypeScript function on Deno runtime handling:
- Anti-exploit validation (minimum distance/elevation thresholds)
- Logarithmic XP formula with activity-specific multipliers
- Streak continuity detection with day-boundary edge case handling
- Daily XP cap enforcement (progressive throttle at 5,000 and hard cap at 10,000)
- Automatic level-up loop with `50 × level^1.8` curve
- Tier/subtier assignment with Obsidian gating requirements
- Atomic upsert to prevent race conditions

### Stored Procedures
- `register_hobby()`: Normalized hobby registration with `ON CONFLICT` upsert and usage counting
- `handle_new_ascend_profile()`: Auto-creates progression profile on user signup

---

## AI Integration

The Claude API integration provides personalized mountaineering coaching:

1. **Structured Onboarding**: Collects 15+ data points (biometrics, fitness level, VO2max, experience, goals)
2. **Plan Generation**: Claude generates a multi-phase training plan with station-based progression
3. **Personalization**: Each station includes personalized reasoning explaining "why" this training matters
4. **Timeline Safety**: AI adjusts user-requested timelines based on experience/fitness assessment
5. **Gear Recommendations**: Context-aware equipment suggestions based on goal mountain
6. **Interactive Chat**: Ongoing coaching dialogue for questions and plan adjustments

---

## Design System

- **Theme**: Dark OLED with premium glass morphism effects (frosted glass cards, specular bloom)
- **Typography**: CabinetGrotesk-Bold (headings) + Satoshi-Regular (body) — custom font system
- **Color System**: Semantic tokens with metric-specific atmosphere colors (cyan=load, gold=duration, green=distance, pink=elevation)
- **Components**: Reusable ViewModifiers (GlassCardModifier, AscentButtonStyle), MetricCard, ReadinessRing, StatPill
- **Animations**: Spring physics (response: 0.35, dampingFraction: 0.78), shimmer effects, neon sweep, 3D specular highlights
- **Haptics**: Centralized HapticManager for tactile feedback across interactions

---

## Skills & Technologies Applied

### iOS / Apple Ecosystem
- SwiftUI (declarative UI, state management, animations, gestures)
- UIKit interop via UIViewRepresentable (Mapbox, WKWebView, document pickers)
- HealthKit (queries, anchored observations, background delivery)
- CoreLocation (GPS tracking, background updates, geofencing)
- CoreMotion (barometric altimeter, altitude deltas)
- ActivityKit (Live Activities, Dynamic Island)
- AVFoundation (text-to-speech for navigation)
- CoreHaptics (haptic feedback patterns)
- Swift Charts (interactive data visualization)
- WebKit (WKWebView with JavaScript bridge)
- PhotosUI (image picker integration)
- MessageUI (email/SMS composition)
- WidgetKit (home screen and lock screen widgets)

### Backend & Cloud
- Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions)
- PostgreSQL (schema design, RLS policies, stored procedures, triggers)
- Deno runtime (TypeScript serverless functions)
- RESTful API design and JWT authentication

### Data & Algorithms
- Haversine distance calculation for GPS coordinates
- Google Polyline Algorithm (encode/decode for compact route storage)
- Bearing calculation (atan2 trigonometry for navigation)
- Sliding window noise filters (elevation smoothing)
- Logarithmic XP formulas with multi-factor multipliers
- Acute-to-Chronic Workload Ratio (ACWR) for training load
- Wind chill calculation (JAG/TI model)
- Freezing level estimation (atmospheric lapse rate)
- Gradient classification algorithms (grade percentage thresholds)
- Auto-pause detection (GPS drift standard deviation analysis)

### APIs & Integrations
- Claude API (Anthropic) — AI coaching and plan generation
- Mapbox Maps SDK — satellite, terrain, tile overlays
- MapLibre GL JS — 3D cinematic route replay
- EAWS API — European avalanche bulletins
- SLF API — Swiss avalanche service
- OpenMeteo API — weather forecasting
- OpenWeatherMap — weather tile layers
- RainViewer API — precipitation radar

### Software Engineering
- MVVM architecture with reactive state management (Combine + SwiftUI)
- Centralized state hub pattern (1,400+ LOC AppState)
- Modular service architecture (singleton managers with clear boundaries)
- Bidirectional native ↔ web bridge (Swift ↔ JavaScript via WKWebView)
- XML parsing (GPX 1.1 import with NSXMLParserDelegate)
- XML generation (GPX/KML export with entity escaping)
- Security-scoped resource access (sandbox-safe file import)
- Background processing with async/await and MainActor isolation
- Server-side anti-exploit validation and rate limiting
- Row Level Security for multi-tenant data isolation
- Custom design system with semantic tokens and reusable components

---

## Project Metrics

| Metric | Value |
|--------|-------|
| **Total Swift LOC** | ~37,000 |
| **Source Files** | 80+ |
| **Supabase Tables** | 6+ with RLS |
| **Edge Functions** | XP calculation engine |
| **External API Integrations** | 8+ |
| **Apple Frameworks Used** | 12+ |
| **Custom Algorithms** | 10+ |

---

*Built as a solo full-stack project — from database schema to pixel-perfect UI.*
