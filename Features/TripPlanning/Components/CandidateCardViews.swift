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
    
    public init(
        transport: TransportOption,
        travelers: Int,
        currency: String = "INR",
        rationale: RecommendationRationale? = nil
    ) {
        self.transport = transport
        self.travelers = travelers
        self.currency = currency
        self.rationale = rationale
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Image(systemName: transport.mode.iconName)
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RECOMMENDED TRANSIT (\(transport.mode.rawValue.uppercased()))")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text(transport.title)
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                
                Spacer()
                
                FreshnessBadgeView(metadata: transport.metadata)
            }
            
            // Route details
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transport.departureStation)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Departure")
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
                    
                    Text(transport.stops == 0 ? "Non-stop" : "\(transport.stops) stop")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(transport.arrivalStation)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Arrival")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.06))
            )
            
            // Pricing
            let total = transport.totalPrice(for: travelers)
            HStack {
                Text("\(currency) \(Int(transport.pricePerPerson)) / traveler")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Total: \(currency) \(Int(total)) for \(travelers)")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            
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
