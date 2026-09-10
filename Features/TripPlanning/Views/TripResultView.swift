import SwiftUI

public struct TripResultView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TripResultViewModel
    
    public init(itinerary: TripItinerary) {
        _viewModel = State(initialValue: TripResultViewModel(itinerary: itinerary))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    overviewHeader
                    
                    if viewModel.revalidationStatus != nil {
                        revalidationBanner
                    }
                    
                    PriceBreakdownBar(
                        totalBudget: viewModel.itinerary.totalBudget,
                        estimatedCost: viewModel.itinerary.totalEstimatedCost,
                        currency: viewModel.itinerary.currency
                    )
                    .padding(.horizontal)
                    
                    if viewModel.itinerary.selectedTransportation != nil {
                        transportSection
                    }
                    
                    if viewModel.itinerary.selectedHotel != nil {
                        hotelSection
                    }
                    
                    if viewModel.itinerary.geminiNarrative != nil {
                        narrativeSection
                    }
                    
                    itinerarySection
                    
                    conversationalModificationSection
                }
                .padding(.vertical)
            }
            .navigationTitle(viewModel.itinerary.destination)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.revalidateLivePrices()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button {
                            Task {
                                await viewModel.saveTrip()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                                Text(viewModel.isSaved ? "Saved" : "Save")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Overview Header
    
    @ViewBuilder
    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(viewModel.itinerary.numberOfDays) DAYS • \(viewModel.itinerary.travelersCount) TRAVELERS")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: viewModel.itinerary.groupType.iconName)
                    Text(viewModel.itinerary.groupType.rawValue)
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.blue.opacity(0.12)))
                .foregroundColor(.blue)
            }
            
            Text("\(viewModel.itinerary.origin) → \(viewModel.itinerary.destination)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Revalidation Banner
    
    @ViewBuilder
    private var revalidationBanner: some View {
        if let status = viewModel.revalidationStatus {
            HStack(spacing: 8) {
                if viewModel.isRevalidating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
            .padding(.horizontal)
        }
    }
    
    // MARK: - Transportation Section
    
    @ViewBuilder
    private var transportSection: some View {
        if let transport = viewModel.itinerary.selectedTransportation {
            VStack(alignment: .leading, spacing: 8) {
                Text("Transportation")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                TransportCardView(
                    transport: transport,
                    travelers: viewModel.itinerary.travelersCount,
                    currency: viewModel.itinerary.currency,
                    rationale: viewModel.itinerary.rationale(for: transport.id.uuidString)
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Accommodation Section
    
    @ViewBuilder
    private var hotelSection: some View {
        if let hotel = viewModel.itinerary.selectedHotel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Accommodation")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                HotelCardView(
                    hotel: hotel,
                    travelers: viewModel.itinerary.travelersCount,
                    nights: max(1, viewModel.itinerary.numberOfDays - 1),
                    currency: viewModel.itinerary.currency,
                    rationale: viewModel.itinerary.rationale(for: hotel.id)
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Narrative Section
    
    @ViewBuilder
    private var narrativeSection: some View {
        if let narrative = viewModel.itinerary.geminiNarrative {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.indigo)
                    Text("Gemini AI Itinerary Overview")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                    Spacer()
                }
                .padding(.horizontal)
                
                Text(narrative)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.indigo.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.18), lineWidth: 1))
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Day-by-Day Itinerary Section
    
    @ViewBuilder
    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day-by-Day Itinerary")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.itinerary.days) { day in
                        let isSelected = viewModel.selectedDayNumber == day.dayNumber
                        Button {
                            viewModel.selectedDayNumber = day.dayNumber
                        } label: {
                            VStack(spacing: 2) {
                                Text("Day \(day.dayNumber)")
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .bold : .regular)
                                Text("\(day.activities.count) activities")
                                    .font(.caption2)
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            if let currentDay = viewModel.currentDayItinerary {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentDay.themeTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(currentDay.narrative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let weather = currentDay.weather {
                            HStack(spacing: 4) {
                                Image(systemName: weather.iconName)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(weather.tempSummary)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(6)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                        }
                    }
                    .padding(.horizontal)
                    
                    ForEach(currentDay.activities) { act in
                        ActivityRowView(activity: act, currency: viewModel.itinerary.currency)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // MARK: - Conversational Modification Bar
    
    @ViewBuilder
    private var conversationalModificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.blue)
                Text("Modify with Gemini AI")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if viewModel.isModifying {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text("Request changes such as 'Make it cheaper', 'Switch to scenic train', or 'Add more outdoor activities'. Grounded candidates will be re-ranked in real time.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickPromptChip("Give me something cheaper")
                    quickPromptChip("Switch to scenic train")
                    quickPromptChip("Upgrade to flights")
                    quickPromptChip("More relaxation pace")
                }
            }
            
            HStack {
                TextField("Ask AI to tweak this itinerary...", text: $viewModel.modificationInputText)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    let text = viewModel.modificationInputText
                    let originalReq = TripRequest(
                        origin: viewModel.itinerary.origin,
                        destination: viewModel.itinerary.destination,
                        numberOfDays: viewModel.itinerary.numberOfDays,
                        travelersCount: viewModel.itinerary.travelersCount,
                        groupType: viewModel.itinerary.groupType,
                        budget: viewModel.itinerary.totalBudget,
                        currency: viewModel.itinerary.currency
                    )
                    Task {
                        await viewModel.applyModification(prompt: text, originalRequest: originalReq)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(viewModel.isModifying || viewModel.modificationInputText.isEmpty)
            }
            
            if let feedback = viewModel.aiModificationFeedback {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.indigo)
                        .padding(.top, 2)
                    Text(feedback)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.indigo.opacity(0.08)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func quickPromptChip(_ prompt: String) -> some View {
        Button {
            viewModel.modificationInputText = prompt
            let originalReq = TripRequest(
                origin: viewModel.itinerary.origin,
                destination: viewModel.itinerary.destination,
                numberOfDays: viewModel.itinerary.numberOfDays,
                travelersCount: viewModel.itinerary.travelersCount,
                groupType: viewModel.itinerary.groupType,
                budget: viewModel.itinerary.totalBudget,
                currency: viewModel.itinerary.currency
            )
            Task {
                await viewModel.applyModification(prompt: prompt, originalRequest: originalReq)
            }
        } label: {
            Text(prompt)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}
