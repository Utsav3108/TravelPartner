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
    public var onSelectConnectingSegmentClass: ((Int, String) -> Void)? = nil
    public var onSelectAlternativeTrain: ((TransportOption) -> Void)? = nil
    
    @State private var showingAlternatives: Bool = true
    
    public init(
        transport: TransportOption,
        travelers: Int,
        currency: String = "INR",
        rationale: RecommendationRationale? = nil,
        onSelectClass: ((String) -> Void)? = nil,
        onSelectConnectingSegmentClass: ((Int, String) -> Void)? = nil,
        onSelectAlternativeTrain: ((TransportOption) -> Void)? = nil
    ) {
        self.transport = transport
        self.travelers = travelers
        self.currency = currency
        self.rationale = rationale
        self.onSelectClass = onSelectClass
        self.onSelectConnectingSegmentClass = onSelectConnectingSegmentClass
        self.onSelectAlternativeTrain = onSelectAlternativeTrain
    }
    
    public var body: some View {
        if let connecting = transport.connectingJourney {
            connectingTransportBody(connecting)
        } else {
            directTransportBody
        }
    }
    
    @ViewBuilder
    private var directTransportBody: some View {
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
    private var unverifiedFareNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .padding(.top, 2)
            
            Text("Unverified Fare: Live PRS fare could not be fetched due to API limits. Fare is estimated based on railway distance. Please verify on IRCTC.")
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }
    
    @ViewBuilder
    private var routeSection: some View {
        let depInfo = formatDateTimeWithDay(transport.departureTime)
        let arrInfo = formatDateTimeWithDay(transport.arrivalTime, relativeTo: transport.departureTime)
        
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(cleanStationName(transport.departureStation))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(depInfo.time)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(depInfo.date)
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
                .padding(.top, 4)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text(cleanStationName(transport.arrivalStation))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(arrInfo.time)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(arrInfo.date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !transport.isFareVerified {
                unverifiedFareNotice
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
                                if !fare.isVerified {
                                    Text("Unverified")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
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
                    
                    let altDep = formatDateTimeWithDay(altTrain.departureTime)
                    let altArr = formatDateTimeWithDay(altTrain.arrivalTime, relativeTo: altTrain.departureTime)
                    HStack(spacing: 4) {
                        Text("\(altDep.date) • \(altDep.time)")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                        Text("\(altArr.date) • \(altArr.time)")
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
    
    // MARK: - Connecting Journey UI Components
    
    @ViewBuilder
    private func connectingTransportBody(_ connecting: TrainConnectingJourney) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            connectingHeaderSection(connecting)
            connectingTimelineSection(connecting)
            connectingClassFaresSection(connecting)
            connectingPriceSummarySection(connecting)
            connectingRationaleSection(connecting)
            if !transport.alternativeOptions.isEmpty {
                connectingAlternativesSection
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
    private func connectingHeaderSection(_ connecting: TrainConnectingJourney) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "tram.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.12)))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
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
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                            Text("✓ Your Selected Journey")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                    
                    if !transport.isFareVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                            Text("Unverified Fare")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Live Verified")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Text(transport.title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("2 trains • \(connecting.connection.formattedLayover) layover • \(connecting.formattedTotalDuration) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func connectingTimelineSection(_ connecting: TrainConnectingJourney) -> some View {
        let leg1 = connecting.segments[0]
        let leg2 = connecting.segments.count > 1 ? connecting.segments[1] : leg1
        
        VStack(spacing: 0) {
            // Segment 1
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 22, height: 22)
                    Text("1")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Train \(leg1.trainNumber) – \(leg1.trainName)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        Spacer()
                        let leg1Class = leg1.selectedClassCode ?? leg1.seatClass
                        Text("\(leg1Class) • \(currency) \(Int(leg1.pricePerPerson))")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cleanStationName(leg1.originStation))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(formatTime(leg1.departureTime))
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(formatDayAndDate(leg1.departureTime, relativeTo: leg1.departureTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(leg1.formattedDuration)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(cleanStationName(leg1.destinationStation))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(formatTime(leg1.arrivalTime))
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(formatDayAndDate(leg1.arrivalTime, relativeTo: leg1.departureTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                }
            }
            
            // Layover connection
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    DashedLine().frame(width: 1, height: 10)
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    DashedLine().frame(width: 1, height: 10)
                }
                .frame(width: 22)
                
                HStack {
                    Text("Layover at \(connecting.connection.stationName)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("\(connecting.connection.formattedLayover)  >")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.10)))
            }
            .padding(.vertical, 4)
            
            // Segment 2
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 22, height: 22)
                    Text("2")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Train \(leg2.trainNumber) – \(leg2.trainName)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        Spacer()
                        let leg2Class = leg2.selectedClassCode ?? leg2.seatClass
                        Text("\(leg2Class) • \(currency) \(Int(leg2.pricePerPerson))")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cleanStationName(leg2.originStation))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(formatTime(leg2.departureTime))
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(formatDayAndDate(leg2.departureTime, relativeTo: leg1.departureTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(leg2.formattedDuration)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(cleanStationName(leg2.destinationStation))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(formatTime(leg2.arrivalTime))
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(formatDayAndDate(leg2.arrivalTime, relativeTo: leg1.departureTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                }
            }
        }
    }
    
    @ViewBuilder
    private func connectingClassFaresSection(_ connecting: TrainConnectingJourney) -> some View {
        let leg1 = connecting.segments[0]
        let leg2 = connecting.segments.count > 1 ? connecting.segments[1] : leg1
        
        VStack(alignment: .leading, spacing: 8) {
            if !transport.isFareVerified {
                unverifiedFareNotice
            }
            
            Text("COACH CLASS & FARES (PER TRAIN)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack(alignment: .top, spacing: 10) {
                // Leg 1 Fares Box
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(leg1.trainNumber) – \(leg1.trainName)")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(leg1.classFares) { fare in
                                let isSelected = fare.classCode.uppercased() == (leg1.selectedClassCode ?? leg1.seatClass).uppercased()
                                Button {
                                    onSelectConnectingSegmentClass?(0, fare.classCode)
                                } label: {
                                    VStack(spacing: 2) {
                                        HStack(spacing: 2) {
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 9))
                                            }
                                            Text(fare.classCode)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                        }
                                        Text("₹\(Int(fare.totalFare))")
                                            .font(.system(size: 9))
                                            .fontWeight(.semibold)
                                        if !fare.isVerified {
                                            Text("Unverified")
                                                .font(.system(size: 7, weight: .bold))
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 46)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? Color.blue : Color.secondary.opacity(0.08))
                                    )
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                
                // Leg 2 Fares Box
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(leg2.trainNumber) – \(leg2.trainName)")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(leg2.classFares) { fare in
                                let isSelected = fare.classCode.uppercased() == (leg2.selectedClassCode ?? leg2.seatClass).uppercased()
                                Button {
                                    onSelectConnectingSegmentClass?(1, fare.classCode)
                                } label: {
                                    VStack(spacing: 2) {
                                        HStack(spacing: 2) {
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 9))
                                            }
                                            Text(fare.classCode)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                        }
                                        Text("₹\(Int(fare.totalFare))")
                                            .font(.system(size: 9))
                                            .fontWeight(.semibold)
                                        if !fare.isVerified {
                                            Text("Unverified")
                                                .font(.system(size: 7, weight: .bold))
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 46)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? Color.blue : Color.secondary.opacity(0.08))
                                    )
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
            }
        }
    }
    
    @ViewBuilder
    private func connectingPriceSummarySection(_ connecting: TrainConnectingJourney) -> some View {
        let total = transport.totalPrice(for: travelers)
        HStack {
            Text("\(currency) \(Int(transport.pricePerPerson)) / traveler (\(connecting.combinedClassSummary))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Total: \(currency) \(Int(total)) for \(travelers)")
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }
    
    @ViewBuilder
    private func connectingRationaleSection(_ connecting: TrainConnectingJourney) -> some View {
        let text = transport.geminiSelectionRationale ?? rationale?.headline
        if let rationaleText = text {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.indigo)
                    .font(.caption)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Why this journey?")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                    Text(rationaleText)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.indigo.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
        }
    }
    
    @ViewBuilder
    private var connectingAlternativesSection: some View {
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
                    Text("Other Connecting Options (\(transport.alternativeOptions.count) more)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Spacer()
                    Text(showingAlternatives ? "Hide" : "Show")
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
                    ForEach(transport.alternativeOptions) { alt in
                        connectingAlternativeCard(alt)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
    
    @ViewBuilder
    private func connectingAlternativeCard(_ alt: TransportOption) -> some View {
        let altLayover = alt.connectingJourney?.connection.formattedLayover ?? "2h"
        let altTotalCost = alt.totalPrice(for: travelers)
        
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("2 trains • \(altLayover) layover • \(alt.formattedDuration)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    onSelectAlternativeTrain?(alt)
                } label: {
                    HStack(spacing: 2) {
                        Text("View Details")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
            }
            
            Text(alt.routeCode)
                .font(.subheadline)
                .fontWeight(.bold)
            
            HStack(spacing: 6) {
                if let segments = alt.connectingJourney?.segments, segments.count >= 2 {
                    let s1 = segments[0]
                    let s2 = segments[1]
                    Text("\(s1.trainNumber) (\(s1.selectedClassCode ?? s1.seatClass) ₹\(Int(s1.pricePerPerson)))")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                    
                    Text("+")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(s2.trainNumber) (\(s2.selectedClassCode ?? s2.seatClass) ₹\(Int(s2.pricePerPerson)))")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text("\(currency) \(Int(altTotalCost)) for \(travelers)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectAlternativeTrain?(alt)
        }
    }
}

// MARK: - View Helpers

private struct DashedLine: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .foregroundColor(Color.secondary.opacity(0.4))
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private func cleanStationName(_ name: String) -> String {
    return name.components(separatedBy: " (").first ?? name
}

private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}

private func formatDayAndDate(_ date: Date, relativeTo baseDate: Date) -> String {
    let cal = Calendar.current
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: baseDate), to: cal.startOfDay(for: date)).day ?? 0
    let dayNumber = max(1, days + 1)
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, d MMM"
    return "Day \(dayNumber) • \(formatter.string(from: date))"
}

private func formatDateTimeWithDay(_ date: Date, relativeTo baseDate: Date? = nil) -> (time: String, date: String) {
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mm a"
    let timeStr = timeFormatter.string(from: date)
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEE, d MMM"
    let datePart = dateFormatter.string(from: date)
    
    if let base = baseDate {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: cal.startOfDay(for: date)).day ?? 0
        if days > 0 {
            return (timeStr, "\(datePart) (Day \(days + 1))")
        }
    }
    return (timeStr, datePart)
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
