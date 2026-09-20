import SwiftUI

public struct HotelCardView: View {
    public let hotel: HotelCandidate
    public let travelers: Int
    public let nights: Int
    public let currency: String
    public let rationale: RecommendationRationale?
    public var onSwapHotel: (() -> Void)? = nil
    
    public init(
        hotel: HotelCandidate,
        travelers: Int,
        nights: Int,
        currency: String = "INR",
        rationale: RecommendationRationale? = nil,
        onSwapHotel: (() -> Void)? = nil
    ) {
        self.hotel = hotel
        self.travelers = travelers
        self.nights = nights
        self.currency = currency
        self.rationale = rationale
        self.onSwapHotel = onSwapHotel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECOMMENDED ACCOMMODATION")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(hotel.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", hotel.reviewScore))
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        
                        Text("(\(hotel.reviewCount) reviews)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(String(format: "%.1f", hotel.distanceToCenterKm)) km to center")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                FreshnessBadgeView(metadata: hotel.metadata)
            }
            
            // Pricing and Rooms Summary
            let rooms = hotel.roomsRequired(for: travelers)
            let total = hotel.totalCost(for: travelers, nights: nights)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(currency) \(Int(hotel.pricePerNight)) / night")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(rooms) \(rooms == 1 ? "room" : "rooms") for \(travelers) guests (\(nights) \(nights == 1 ? "night" : "nights"))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Stay Cost")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(currency) \(Int(total))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.06))
            )
            
            // Amenities
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(hotel.amenities.prefix(5)), id: \.self) { amenity in
                        Text(amenity)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    }
                }
            }
            
            // Rationale
            if let rationale = rationale {
                RationaleCardView(rationale: rationale)
            }
        }
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
}

public struct TransportCardView: View {
    public let transport: TransportOption
    public let travelers: Int
    public let currency: String
    public let rationale: RecommendationRationale?
    public var onSelectClass: ((String) -> Void)? = nil
    public var onSelectAlternativeTrain: ((TransportOption) -> Void)? = nil
    
    @State private var showingAlternatives: Bool = true
    
    public init(
        transport: TransportOption,
        travelers: Int,
        currency: String = "INR",
        rationale: RecommendationRationale? = nil,
        onSelectClass: ((String) -> Void)? = nil,
        onSelectAlternativeTrain: ((TransportOption) -> Void)? = nil
    ) {
        self.transport = transport
        self.travelers = travelers
        self.currency = currency
        self.rationale = rationale
        self.onSelectClass = onSelectClass
        self.onSelectAlternativeTrain = onSelectAlternativeTrain
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            routeSection
            if !transport.classFares.isEmpty {
                classFaresSection
            }
            priceSummarySection
            rationaleSection
            if !transport.alternativeOptions.isEmpty {
                alternativesSection
            }
        }
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
    
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Image(systemName: transport.mode.iconName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.blue.opacity(0.12)))
                
                VStack(alignment: .leading, spacing: 4) {
                    if transport.isRecommended {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                            Text("Recommended")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                    
                    Text(transport.title)
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            
            Spacer()
            
            FreshnessBadgeView(metadata: transport.metadata)
        }
    }
    
    @ViewBuilder
    private var routeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transport.departureStation)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(DateFormatter.localizedString(from: transport.departureTime, dateStyle: .none, timeStyle: .short))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(transport.formattedDuration)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(transport.stops == 0 ? "Direct" : "\(transport.stops) stop")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(transport.arrivalStation)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(DateFormatter.localizedString(from: transport.arrivalTime, dateStyle: .none, timeStyle: .short))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.06))
        )
    }
    
    @ViewBuilder
    private var classFaresSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("COACH CLASS & PRS FARES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if let selected = transport.selectedClassCode {
                    Text("Selected: \(selected)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(transport.classFares) { fare in
                        let isSelected = (fare.classCode.uppercased() == (transport.selectedClassCode ?? "").uppercased())
                        Button {
                            onSelectClass?(fare.classCode)
                        } label: {
                            HStack(spacing: 4) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                }
                                Text(fare.classCode)
                                    .fontWeight(.bold)
                                Text("•")
                                    .font(.caption2)
                                Text("\(currency) \(Int(fare.totalFare))")
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.08))
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if let selectedFare = transport.selectedClassFare {
                HStack(spacing: 8) {
                    if let base = selectedFare.baseFare {
                        Text("Base: \(currency)\(Int(base))")
                    }
                    if let sf = selectedFare.superfastCharge, sf > 0 {
                        Text("SF: \(currency)\(Int(sf))")
                    }
                    if let gst = selectedFare.gst, gst > 0 {
                        Text("GST: \(currency)\(Int(gst))")
                    }
                    if let res = selectedFare.reservationCharge, res > 0 {
                        Text("Res: \(currency)\(Int(res))")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }
        }
    }
    
    @ViewBuilder
    private var priceSummarySection: some View {
        let total = transport.totalPrice(for: travelers)
        let classSuffix = transport.selectedClassCode.map { " (\($0))" } ?? ""
        HStack {
            Text("\(currency) \(Int(transport.pricePerPerson)) / traveler\(classSuffix)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Total: \(currency) \(Int(total)) for \(travelers)")
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }
    
    @ViewBuilder
    private var rationaleSection: some View {
        if let geminiRationale = transport.geminiSelectionRationale {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.indigo)
                    .font(.caption)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Why this train?")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                    Text(geminiRationale)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.indigo.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
            )
        } else if let rationale = rationale {
            RationaleCardView(rationale: rationale)
        }
    }
    
    @ViewBuilder
    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingAlternatives.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "tram.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Available Trains for Journey (\(transport.alternativeOptions.count) other)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Spacer()
                    Text(showingAlternatives ? "Hide" : "Show & Change")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(systemName: showingAlternatives ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(8)
                .background(Color.blue.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            if showingAlternatives {
                VStack(spacing: 8) {
                    ForEach(transport.alternativeOptions) { altTrain in
                        alternativeTrainRow(altTrain)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
    
    @ViewBuilder
    private func alternativeTrainRow(_ altTrain: TransportOption) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(altTrain.title)
                            .font(.caption)
                            .fontWeight(.bold)
                        
                        if altTrain.isRecommended {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                Text("Recommended")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(DateFormatter.localizedString(from: altTrain.departureTime, dateStyle: .none, timeStyle: .short))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                        Text(DateFormatter.localizedString(from: altTrain.arrivalTime, dateStyle: .none, timeStyle: .short))
                        Text("•")
                        Text(altTrain.formattedDuration)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    onSelectAlternativeTrain?(altTrain)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .bold))
                        Text("Change Train")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            if let note = altTrain.geminiSelectionRationale {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            if !altTrain.classFares.isEmpty {
                HStack(spacing: 6) {
                    ForEach(altTrain.classFares) { fare in
                        Button {
                            var chosen = altTrain
                            chosen.updateSelectedClass(code: fare.classCode)
                            onSelectAlternativeTrain?(chosen)
                        } label: {
                            HStack(spacing: 2) {
                                Text(fare.classCode)
                                    .fontWeight(.bold)
                                Text(":\(currency)\(Int(fare.totalFare))")
                            }
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

public struct ActivityRowView: View {
    public let activity: ItineraryActivity
    public let currency: String
    
    public init(activity: ItineraryActivity, currency: String = "INR") {
        self.activity = activity
        self.currency = currency
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Transit Pill from previous location
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(activity.transitSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.08))
            )
            
            // Activity Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(activity.timeSlot.rawValue)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                                .foregroundColor(.blue)
                            
                            Text(activity.scheduledTimeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(activity.place.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", activity.place.rating))
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                
                Text(activity.place.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: activity.place.category.iconName)
                            .font(.caption2)
                        Text(activity.place.category.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(activity.estimatedCost == 0 ? "Free Entry" : "\(currency) \(Int(activity.estimatedCost)) entry")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(activity.estimatedCost == 0 ? .green : .primary)
                }
                
                // Local tip
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    Text(activity.localTip)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.08)))
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
    }
}
