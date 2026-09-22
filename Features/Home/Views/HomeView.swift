import SwiftUI

public struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingWizard: Bool = false
    @State private var activeRequest: TripRequest? = nil
    @State private var showingPlanning: Bool = false
    @State private var selectedItinerary: TripItinerary? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Header Banner
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("EXPLORE & PLAN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Spacer()

                        }
                        
                        Text("Where to next?")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text("Describe your trip in plain English or customize your parameters with live pricing & on-device personalization.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Natural Language AI Input Box
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.indigo)
                            Text("AI Travel Assistant")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.indigo)
                            Spacer()
                            if viewModel.isParsing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        TextEditor(text: $viewModel.promptText)
                            .frame(minHeight: 70, maxHeight: 110)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
                            )
                            .font(.body)
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Trip Date (Constrained to Current Month)
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                            
                            DatePicker(
                                "Trip Date (This Month)",
                                selection: $viewModel.tripDate,
                                in: viewModel.currentMonthRange,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.06))
                        )
                        
                        // Inspiration Chips
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TRY AN IDEA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.inspirations) { item in
                                        Button {
                                            viewModel.promptText = item.prompt
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: item.icon)
                                                    .font(.caption2)
                                                Text(item.title)
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(viewModel.promptText == item.prompt ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.08))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(viewModel.promptText == item.prompt ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                            .foregroundColor(viewModel.promptText == item.prompt ? .blue : .primary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    if let request = await viewModel.parsePrompt() {
                                        self.activeRequest = request
                                        self.showingPlanning = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("Plan with AI")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(viewModel.isParsing)
                            
                            Button {
                                showingWizard = true
                            } label: {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Customize")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Featured Destinations
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Popular Destinations")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(viewModel.featuredDestinations) { dest in
                                    Button {
                                        let req = viewModel.selectFeatured(dest)
                                        self.activeRequest = req
                                        self.showingPlanning = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: dest.iconName)
                                                    .font(.title2)
                                                    .foregroundColor(.blue)
                                                Spacer()
                                                Text("₹\(Int(dest.suggestedBudget / 1000))k")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                                                    .foregroundColor(.green)
                                            }
                                            
                                            Text(dest.name)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            
                                            Text(dest.subtitle)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            
                                            HStack(spacing: 4) {
                                                ForEach(dest.tags, id: \.self) { tag in
                                                    Text(tag)
                                                        .font(.caption2)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .frame(width: 220, alignment: .leading)
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(white: 0.98))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Recent Trips
                    if !viewModel.recentTrips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Itineraries")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.recentTrips.prefix(3)) { trip in
                                Button {
                                    self.selectedItinerary = trip
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(trip.destination)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("\(trip.numberOfDays) days • \(trip.travelersCount) \(trip.groupType.rawValue.lowercased()) • \(trip.currency) \(Int(trip.totalEstimatedCost))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(white: 0.98))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Travel Partner")
            .sheet(isPresented: $showingWizard) {
                TripWizardView { request in
                    self.showingWizard = false
                    self.activeRequest = request
                    self.showingPlanning = true
                }
            }
            .sheet(isPresented: $showingPlanning) {
                if let req = activeRequest {
                    PlanningProgressView(request: req) { itinerary in
                        self.showingPlanning = false
                        self.selectedItinerary = itinerary
                    } onCancel: {
                        self.showingPlanning = false
                    }
                }
            }
            .sheet(item: $selectedItinerary) { itinerary in
                TripResultView(itinerary: itinerary)
            }
            .task {
                await viewModel.loadRecentTrips()
            }
        }
    }
}
