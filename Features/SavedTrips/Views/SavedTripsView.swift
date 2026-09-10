import SwiftUI

public struct SavedTripsView: View {
    @State private var viewModel = SavedTripsViewModel()
    @State private var selectedTrip: TripItinerary? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading saved trips...")
                } else if viewModel.filteredTrips.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Saved Trips Yet")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Generate a personalized itinerary with AI and tap the bookmark button to sync it to Firebase.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filteredTrips) { trip in
                            Button {
                                self.selectedTrip = trip
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("\(trip.origin) → \(trip.destination)")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text("\(trip.currency) \(Int(trip.totalEstimatedCost))")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Text("\(trip.numberOfDays) days")
                                        Text("•")
                                        Text("\(trip.travelersCount) (\(trip.groupType.rawValue))")
                                        Text("•")
                                        if let hotel = trip.selectedHotel {
                                            Text(hotel.name)
                                                .lineLimit(1)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let trip = viewModel.filteredTrips[index]
                                Task {
                                    await viewModel.deleteTrip(id: trip.id)
                                }
                            }
                        }
                    }
                    .searchable(text: $viewModel.searchText, prompt: "Search by city...")
                }
            }
            .navigationTitle("My Trips")
            .task {
                await viewModel.loadTrips()
            }
            .sheet(item: $selectedTrip) { trip in
                TripResultView(itinerary: trip)
            }
        }
    }
}
