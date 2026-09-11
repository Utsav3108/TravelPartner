import SwiftUI

public struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showingDiagnostics: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Gemini AI Secret Management
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.indigo)
                            Text("Gemini API Key")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.isKeyConfigured ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.isKeyConfigured ? "Active" : "Offline Fallback")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(viewModel.isKeyConfigured ? .green : .orange)
                            }
                        }
                        
                        Text("Current: \(viewModel.maskedKeyString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Active Engine: \(viewModel.aiEngineStatus)")
                            .font(.caption2)
                            .foregroundColor(.indigo)
                            .fontWeight(.medium)
                        
                        SecureField("Paste new Gemini API key", text: $viewModel.newGeminiApiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack(spacing: 8) {
                            Button("Save Key") {
                                viewModel.saveGeminiKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.newGeminiApiKey.isEmpty)
                            
                            Button {
                                Task {
                                    await viewModel.testCloudConnection()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if viewModel.isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "bolt.horizontal.fill")
                                    }
                                    Text("Test Connection")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isTestingConnection)
                            
                            if viewModel.isKeyConfigured {
                                Button("Remove") {
                                    viewModel.clearGeminiKey()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                        
                        if let testMsg = viewModel.connectionTestMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: viewModel.connectionTestIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(viewModel.connectionTestIsSuccess ? .green : .orange)
                                    Text(testMsg)
                                        .font(.caption2)
                                        .foregroundColor(viewModel.connectionTestIsSuccess ? .primary : .orange)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.connectionTestIsSuccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.12))
                            )
                        }
                        
                        if let feedback = viewModel.saveFeedback {
                            Text(feedback)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Generative AI Configuration")
                } footer: {
                    Text("API keys are never stored in source control. You can obtain a free key at aistudio.google.com.")
                }
                
                // Section 2: Traveler Profile
                Section {
                    HStack {
                        Text("Display Name")
                        Spacer()
                        TextField("Name", text: $viewModel.profile.displayName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        TextField("Email", text: $viewModel.profile.email)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Default Currency", selection: $viewModel.profile.preferredCurrency) {
                        Text("INR (₹)").tag("INR")
                        Text("USD ($)").tag("USD")
                        Text("EUR (€)").tag("EUR")
                    }
                    
                    Picker("Default Group", selection: $viewModel.profile.defaultGroupType) {
                        ForEach(GroupType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Default Pace", selection: $viewModel.profile.defaultPace) {
                        ForEach(PacePreference.allCases, id: \.self) { pace in
                            Text(pace.rawValue).tag(pace)
                        }
                    }
                } header: {
                    Text("Traveler Preferences")
                }
                
                // Section 3: Engine Architecture Settings
                Section {
                    Picker("Search Provider", selection: Binding(
                        get: { viewModel.searchMode },
                        set: { viewModel.updateSearchMode($0) }
                    )) {
                        ForEach(AppConfiguration.SearchMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    Picker("Recommendation Engine", selection: Binding(
                        get: { viewModel.mlMode },
                        set: { viewModel.updateMLMode($0) }
                    )) {
                        ForEach(AppConfiguration.MLEngineMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                } header: {
                    Text("Engine Runtime Modes")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Core ML executes candidate ranking on-device to protect personal preference privacy.")
                        Text("Status: \(viewModel.coreMLStatus)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Section 4: System Architecture & Diagnostics
                Section {
                    Button {
                        showingDiagnostics = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                                .foregroundColor(.blue)
                            Text("Architecture & Concurrency Diagnostics")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Clear Volatile Travel Cache") {
                        Task {
                            await TravelDataCacheActor.shared.clearAll()
                            viewModel.saveFeedback = "Volatile cache purged."
                        }
                    }
                    .foregroundColor(.orange)
                } header: {
                    Text("Diagnostics")
                }
            }
            .navigationTitle("Profile & Settings")
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticsSheetView()
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }
}

public struct DiagnosticsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("System Architecture Overview")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Travel Partner uses a 5-layer Hybrid AI Architecture:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        diagLayerCard(
                            step: "1",
                            title: "Live Volatile Search (Structured Concurrency)",
                            desc: "Uses Swift TaskGroup to dispatch flights, trains, hotels, and places queries concurrently. Distinguishes live volatile data from Firebase with metadata timestamps and TTL."
                        )
                        diagLayerCard(
                            step: "2",
                            title: "Hard Constraint Engine (Deterministic Rules)",
                            desc: "Strictly deterministic. Validates room capacity (ceil(travelers/capacity)), enforces strict family-safety certification, and prevents budget overflow before ML ranking."
                        )
                        diagLayerCard(
                            step: "3",
                            title: "On-Device ML (Core ML + MCDA)",
                            desc: "Scores candidates locally based on price-to-budget ratio, review scores, proximity, and preference affinity without transmitting raw user signals off-device."
                        )
                        diagLayerCard(
                            step: "4",
                            title: "Itinerary Optimizer (Geographic Clustering)",
                            desc: "Solves TSP/clustering using Haversine distance to minimize daily transit fatigue, slotting places into morning, afternoon, and evening windows."
                        )
                        diagLayerCard(
                            step: "5",
                            title: "Gemini Generative AI (Grounded Reasoning)",
                            desc: "Bridges human communication with natural-language parsing, narrative generation, and grounded conversational modification. Strictly bounded to avoid hallucinating rates."
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnostics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func diagLayerCard(step: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }
}
