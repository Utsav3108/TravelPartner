# Travel Partner — AI Travel Planner (iOS / SwiftUI / Firebase / Gemini / Core ML)

> A production-oriented iOS application delivering personalized, constraint-optimized travel plans via a 5-layer Hybrid AI Architecture. Built with **SwiftUI**, **Swift 6 Concurrency**, **Core ML**, **Google Gemini**, and **Firebase**.

---

## 🌟 Overview

Travel Partner is **not** a simple wrapper around a chatbot. It is a genuine **travel recommendation engine** paired with a conversational generative AI interface.

When a user submits a natural-language request such as:
> *"I want to go to Shimla for 5 days with 4 friends. My total budget is ₹50,000. I want a round trip."*

The application coordinates a structured 10-step planning pipeline:
1. **Natural-Language Understanding**: Gemini via official **Firebase AI SDK** (`FirebaseAI`) parses user prompts into a validated domain entity (`TripRequest`).
2. **Live Volatile Search**: Uses Swift structured concurrency (`TaskGroup`) to query flights, trains, hotels, attractions, and weather concurrently.
3. **Hard Business Constraints**: Enforces non-negotiable budget caps, room capacity equations (`ceil(travelers / capacity)`), and group safety policies deterministically.
4. **On-Device ML Ranking**: Evaluates candidates locally using Apple's **Core ML** framework with 3 dedicated models (Hotels, Places, Transport) and persistent feedback personalization.
5. **Algorithmic Itinerary Optimization**: Clusters places geographically using Haversine distance to minimize transit time, while verifying opening hours across morning, afternoon, and evening slots.
6. **Grounded AI Presentation & Streaming**: Gemini synthesizes engaging itinerary narratives and transparent *"Recommended because:"* rationale bullets without hallucinating prices.
7. **Firebase Persistence**: Persists itineraries and feedback to Firebase Firestore while strictly segregating live volatile travel data from application state.
8. **Interactive AI Modifications**: Users can conversationally command *"Make this cheaper"* or *"Switch to a scenic train"*, and the engine swaps genuine candidates and recalculates costs in real time.

---

## 🏗️ Architecture

For in-depth technical specifications, sequence diagrams, and engineering vocabulary, please consult [ARCHITECTURE.md](file:///Users/utsav/Documents/Projects/TravelPartner/ARCHITECTURE.md).

```
SwiftUI (Declarative Presentation)
   │
   ▼
ViewModels (@Observable + @MainActor)
   │
   ▼
Domain & Pipeline (TripPlanningCoordinator)
   ├── LiveTravelSearchService (TaskGroup Parallel Fetch)
   ├── ConstraintEngine (Deterministic Business Rules)
   ├── CoreMLRecommendationEngine (On-Device Candidate Scoring)
   ├── ItineraryOptimizer (Haversine Spatial Clustering)
   ├── GeminiService (Natural Language Parsing & Synthesis)
   └── FirebaseTripRepository (State & Feedback Persistence)
```

### 📁 Feature-Oriented Project Layout

The codebase is organized into **features + shared architectural layers**, completely separating presentation, domain rules, data access, and AI orchestration:

```text
TravelPartner/
├── App/                            # Application entry point, DI, environment & assets
│   ├── TravelPartnerApp.swift      # @main SwiftUI App definition
│   ├── AppContainer.swift          # Lightweight DI Container (shared & mock instances)
│   ├── AppEnvironment.swift        # Feature flags & runtime environment toggles
│   ├── Info.plist                  # iOS Application bundle property list
│   └── Assets.xcassets             # Colors and image assets
├── Features/                       # Vertical feature slices (View + ViewModel + local UI)
│   ├── Home/                       # Explore screen & natural-language prompt input
│   ├── TripPlanning/               # Interactive Wizard, Live Progress & Itinerary Results
│   ├── SavedTrips/                 # Firestore-persisted itinerary library & search
│   └── Profile/                    # Traveler preferences, AI settings & diagnostic controls
├── Domain/                         # Pure Foundation domain layer (zero UI dependencies)
│   ├── Models/                     # TripRequest, Candidates, Itinerary, UserProfile
│   ├── Rules/                      # BudgetRuleEvaluator, GroupRuleEvaluator, ConstraintEngine
│   └── Services/                   # TripPlanningCoordinator, RecommendationEngine, ItineraryOptimizer
├── Data/                           # Data access, network retrieval & persistence
│   ├── Remote/                     # Search providers, LiveTravelSearchService, CacheActor
│   └── Firebase/                   # Firestore repository, emulated local storage
├── AI/                             # Artificial Intelligence & Machine Learning engines
│   ├── Gemini/                     # Google Gemini NLU, Narrative Synthesis, Conversational Edits
│   └── ML/                         # Core ML ranking engine & MCDA deterministic fallback
├── Configuration/                  # Secrets templates & centralized app configuration
│   ├── AppConfiguration.swift      # Thread-safe settings manager
│   ├── Secrets.example             # Property list secrets template
│   └── Secrets.example.xcconfig    # Xcode xcconfig secrets template
├── Shared/                         # Cross-feature reusable components & utilities
│   ├── Components/                 # MainTabView, FreshnessBadgeView, RationaleCardView
│   └── Errors/                     # TravelPlanningError & typed error representations
└── Tests/
    └── TravelPartnerCoreTests/     # 17 hermetic unit test suites (Swift Testing)
```

### 💉 Dependency Injection (`AppContainer`)

Dependencies are managed through a clean, lightweight `AppContainer` (avoiding untestable global singletons):
* `AppContainer.shared`: Standard production container initializing live search services, Core ML ranking, Gemini, and Firestore.
* `AppContainer.mock`: Hermetic mock container using in-memory Firebase emulation and deterministic fallback engines, ideal for SwiftUI previews and unit tests.


---

## 📋 Requirements

* **macOS**: 14.0+ (Sonoma or Sequoia)
* **Xcode**: 16.0+ (Xcode 26.0+ supported)
* **Swift**: 6.0+ / 6.2 (Fully Swift 6 Sendable and Data-Race Safe)
* **Target Deployment**: iOS 17.0+ (Universal iPhone & iPad)

---

## 🔑 Configuration & Secret Management

In adherence to security best practices, **no API keys, tokens, or credentials are hardcoded or tracked in Git**.

### 1. Adding Google Gemini API Key
You can obtain a free Gemini API key from [Google AI Studio](https://aistudio.google.com/).

You have three options for configuring your key:
* **Option A: In-App UI (Recommended for quick testing)**
  1. Launch the app.
  2. Tap the **Settings** tab (Profile icon).
  3. Under **Generative AI Configuration**, paste your API key into the secure text field and tap **Save Key**. The key will be stored securely in local user defaults.
* **Option B: Local Secrets.plist**
  1. Copy `Configuration/Secrets.example` to `Secrets.plist` (which is in `.gitignore`).
  2. Add your key:
     ```xml
     <dict>
         <key>GEMINI_API_KEY</key>
         <string>AIzaSyYourActualKeyHere</string>
     </dict>
     ```
* **Option C: Local Xcode Config (Secrets.xcconfig)**
  1. Copy `Configuration/Secrets.example.xcconfig` to `Configuration/Secrets.xcconfig` (ignored by Git).
  2. Set `GEMINI_API_KEY = AIzaSyYourActualKeyHere`
* **Option D: Environment Variable**
  Run with:
  ```bash
  export GEMINI_API_KEY="AIzaSyYourActualKeyHere"
  ```

> [!NOTE]
> **Zero-Key Execution**: If no API key is supplied, the app automatically runs in **Offline AI Fallback Mode**. The deterministic NLP engine parses requests and constructs full itineraries without error!

### 2. Adding Firebase Configuration
1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Add an iOS app with Bundle ID `com.travelpartner.ai`.
3. Download `GoogleService-Info.plist` and place it in the root or `App/` directory (it is ignored by Git).
4. The repository includes both the production Firestore adapter (`FirebaseTripRepository`) and an emulated local repository (`LocalFirebaseEmulatedRepository`), allowing full persistence and offline development without an active Google Cloud billing account.

---

## 🚀 How to Run the Application

### Option 1: Open in Xcode (iOS Simulator / Device)
1. Double-click `TravelPartner.xcodeproj` to open the project in Xcode.
2. Select any iPhone simulator (e.g. **iPhone 17** or **iPhone 16 Pro**).
3. Press **Cmd + R** to build and run.

### Option 2: Command Line (xcodebuild)
Build the iOS Simulator bundle:
```bash
xcodebuild -project TravelPartner.xcodeproj \
           -scheme TravelPartner \
           -destination 'generic/platform=iOS Simulator' \
           CODE_SIGNING_ALLOWED=NO \
           CODE_SIGNING_REQUIRED=NO \
           build
```

### Option 3: Swift Package Manager (Terminal)
Build the executable and test targets:
```bash
swift build
```

---

## 🧪 Running Unit Tests

The test suite covers:
* `TripRequest` validation (duration, destination, minimum budget, traveler count)
* Deterministic budget calculations and capacity equations
* Family friendliness constraints and safety policies
* Recommendation ranking and explainable rationale generation
* Spatial itinerary clustering and duration optimization
* Swift Concurrency cancellation (`Task.isCancelled`)
* Graceful degradation under partial provider failures
* Gemini natural-language parsing and conversational modifications
* Firebase emulated persistence and user feedback

### Run tests via SPM:
```bash
swift test
```
*Result: 17 tests across 8 test suites pass in ~0.4 seconds with 0 failures.*

---

## 📱 User Interface Walkthrough

1. **Explore / Home**:
   - Hero prompt bar pre-populated with the example query (*"I want to go to Shimla for 5 days with 4 friends. My total budget is ₹50,000. I want a round trip."*).
   - Featured destinations carousel (Shimla, Manali, Goa, Jaipur) with 1-tap planning.
   - Recent itineraries list.
2. **Custom Trip Wizard**:
   - Step 1: Destination, starting origin, dates, and days.
   - Step 2: Traveler count, group type (Solo, Couple, Friends, Family, Business), and direction (Round Trip / One Way).
   - Step 3: Total budget with live per-traveler and per-day breakdown.
   - Step 4: Interests (Nature, Culture, Adventure, Relaxation, Foodie, etc.), pacing, and dietary options.
3. **Live Planning Progress**:
   - Animated progress ring showing real pipeline milestones:
     * *Finding travel options & hotels...*
     * *Enforcing budget & safety rules...*
     * *Personalizing recommendations (Core ML)...*
     * *Optimizing daily schedule & transit...*
     * *Polishing with Gemini Generative AI...*
     * *Persisting trip to Firebase...*
   - Interactive **Cancel Planning** button that cancels ongoing tasks cooperatively.
4. **Trip Result & Itinerary**:
   - Overview banner with group badge and total budget utilization progress bar.
   - Recommended transportation card (Flight or Train) with duration, departure/arrival, and *"Recommended because:"* rationale bullets.
   - Recommended hotel card with room requirements, pricing, amenities, and rationale bullets.
   - Horizontal day tabs with morning, afternoon, and evening activity cards, inter-activity transit walks/cab pills, opening hours, and local tips.
   - Gemini AI Overview narrative.
   - Interactive AI Modification bar (*"Give me something cheaper"*, *"Switch to scenic train"*).
5. **Saved Trips**:
   - Filterable search list of trips saved in Firebase Firestore.
   - View, share, or delete saved plans.
6. **Profile & Settings**:
   - Traveler preferences, Gemini API key manager with UI masking, and search/ML runtime mode switches.
   - System architecture diagnostics inspector with cache invalidation control.

---

## 🔒 Security & Data Privacy

* **Zero Hardcoded Secrets**: All credentials are read from environment variables or secure user settings.
* **On-Device Personalization**: User preference vectors and ranking scores are evaluated locally using Core ML and MCDA utility functions, eliminating unnecessary cloud data transmission.
* **Bounded Generative AI**: Gemini receives only structured candidate sets to prevent hallucination of volatile airline, railway, or hotel rates.

---

## 📄 License
MIT License. Created for the production-oriented AI Travel Planner project.
