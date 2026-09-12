import SwiftUI

/// Interactive State and City Station Picker for Indian Railways.
/// Displays cities organized by state with station codes and tokens for deterministic API routing.
public struct StationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let title: String
    public let onSelect: (String, String) -> Void
    
    @State private var searchQuery: String = ""
    @State private var selectedState: String? = nil
    
    public init(title: String = "Select Station / City", onSelect: @escaping (String, String) -> Void) {
        self.title = title
        self.onSelect = onSelect
    }
    
    private var filteredStations: [IndianStationItem] {
        let searched = IndianRailwayDirectory.search(query: searchQuery)
        if let st = selectedState {
            return searched.filter { $0.stateName == st }
        }
        return searched
    }
    
    private var groupedStations: [String: [IndianStationItem]] {
        Dictionary(grouping: filteredStations, by: { $0.stateName })
    }
    
    private var sortedStates: [String] {
        groupedStations.keys.sorted()
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search city, state, or token (e.g. Puducherry, DDN, Gujarat)...", text: $searchQuery)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // State Category Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedState = nil
                        } label: {
                            Text("All States")
                                .font(.caption)
                                .fontWeight(selectedState == nil ? .bold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedState == nil ? Color.blue : Color.secondary.opacity(0.1))
                                .foregroundColor(selectedState == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        
                        ForEach(IndianRailwayDirectory.states, id: \.self) { state in
                            Button {
                                selectedState = (selectedState == state) ? nil : state
                            } label: {
                                Text(state)
                                    .font(.caption)
                                    .fontWeight(selectedState == state ? .bold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedState == state ? Color.blue : Color.secondary.opacity(0.1))
                                    .foregroundColor(selectedState == state ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                Divider()
                
                // Grouped Stations List
                List {
                    ForEach(sortedStates, id: \.self) { state in
                        Section(header: Text(state).font(.caption).fontWeight(.bold).foregroundColor(.blue)) {
                            ForEach(groupedStations[state] ?? []) { item in
                                Button {
                                    onSelect(item.cityName, item.stationCode)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.isMajorHub ? "tram.fill" : "tram")
                                            .foregroundColor(item.isMajorHub ? .blue : .secondary)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.cityName)
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            
                                            Text(item.stationName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(item.stationCode)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.12))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    if filteredStations.isEmpty && !searchQuery.isEmpty {
                        Section {
                            VStack(spacing: 10) {
                                Text("No official station preset found for '\(searchQuery)'")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button {
                                    onSelect(searchQuery, "")
                                    dismiss()
                                } label: {
                                    Text("Use '\(searchQuery)' as custom city")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
