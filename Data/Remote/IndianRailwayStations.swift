import Foundation

/// Comprehensive representation of an Indian Railway station mapped to its parent state and city.
public struct IndianStationItem: Identifiable, Hashable, Sendable {
    public var id: String { stationCode }
    public let cityName: String
    public let stateName: String
    public let stationCode: String
    public let stationName: String
    public let isMajorHub: Bool
    
    public init(
        cityName: String,
        stateName: String,
        stationCode: String,
        stationName: String,
        isMajorHub: Bool = false
    ) {
        self.cityName = cityName
        self.stateName = stateName
        self.stationCode = stationCode
        self.stationName = stationName
        self.isMajorHub = isMajorHub
    }
    
    public var displayName: String {
        "\(cityName) (\(stationCode))"
    }
}

/// Curated directory of primary Indian Railway stations organized by State and Union Territory.
public enum IndianRailwayDirectory {
    public static let stations: [IndianStationItem] = [
        // Puducherry (UT)
        IndianStationItem(cityName: "Puducherry", stateName: "Puducherry (UT)", stationCode: "PDY", stationName: "Pondicherry Railway Station", isMajorHub: true),
        
        // Uttarakhand
        IndianStationItem(cityName: "Dehradun", stateName: "Uttarakhand", stationCode: "DDN", stationName: "Dehra Dun Railway Station", isMajorHub: true),
        IndianStationItem(cityName: "Haridwar", stateName: "Uttarakhand", stationCode: "HW", stationName: "Haridwar Junction", isMajorHub: true),
        IndianStationItem(cityName: "Rishikesh", stateName: "Uttarakhand", stationCode: "YNRK", stationName: "Yog Nagari Rishikesh", isMajorHub: false),
        IndianStationItem(cityName: "Kathgodam / Nainital", stateName: "Uttarakhand", stationCode: "KGM", stationName: "Kathgodam Railway Station", isMajorHub: false),
        
        // Delhi NCR
        IndianStationItem(cityName: "New Delhi", stateName: "Delhi NCR", stationCode: "NDLS", stationName: "New Delhi Railway Station", isMajorHub: true),
        IndianStationItem(cityName: "Old Delhi", stateName: "Delhi NCR", stationCode: "DLI", stationName: "Delhi Junction", isMajorHub: true),
        IndianStationItem(cityName: "Hazrat Nizamuddin", stateName: "Delhi NCR", stationCode: "NZM", stationName: "Hazrat Nizamuddin", isMajorHub: true),
        IndianStationItem(cityName: "Anand Vihar", stateName: "Delhi NCR", stationCode: "ANVT", stationName: "Anand Vihar Terminal", isMajorHub: true),
        
        // Gujarat
        IndianStationItem(cityName: "Ahmedabad", stateName: "Gujarat", stationCode: "ADI", stationName: "Ahmedabad Junction", isMajorHub: true),
        IndianStationItem(cityName: "Viramgam", stateName: "Gujarat", stationCode: "VG", stationName: "Viramgam Junction", isMajorHub: true),
        IndianStationItem(cityName: "Surat", stateName: "Gujarat", stationCode: "ST", stationName: "Surat Railway Station", isMajorHub: true),
        IndianStationItem(cityName: "Vadodara", stateName: "Gujarat", stationCode: "BRC", stationName: "Vadodara Junction", isMajorHub: true),
        IndianStationItem(cityName: "Rajkot", stateName: "Gujarat", stationCode: "RJT", stationName: "Rajkot Junction", isMajorHub: false),
        IndianStationItem(cityName: "Bhuj / Kutch", stateName: "Gujarat", stationCode: "BHUJ", stationName: "Bhuj Railway Station", isMajorHub: false),
        
        // Bihar
        IndianStationItem(cityName: "Patna", stateName: "Bihar", stationCode: "PNBE", stationName: "Patna Junction", isMajorHub: true),
        IndianStationItem(cityName: "Gaya", stateName: "Bihar", stationCode: "GAYA", stationName: "Gaya Junction", isMajorHub: false),
        IndianStationItem(cityName: "Muzaffarpur", stateName: "Bihar", stationCode: "MFP", stationName: "Muzaffarpur Junction", isMajorHub: false),
        IndianStationItem(cityName: "Bhagalpur", stateName: "Bihar", stationCode: "BGP", stationName: "Bhagalpur Junction", isMajorHub: false),
        IndianStationItem(cityName: "Darbhanga", stateName: "Bihar", stationCode: "DBG", stationName: "Darbhanga Junction", isMajorHub: false),
        
        // Maharashtra
        IndianStationItem(cityName: "Mumbai (CSMT)", stateName: "Maharashtra", stationCode: "CSMT", stationName: "Chhatrapati Shivaji Maharaj Terminus", isMajorHub: true),
        IndianStationItem(cityName: "Mumbai Central", stateName: "Maharashtra", stationCode: "MMCT", stationName: "Mumbai Central", isMajorHub: true),
        IndianStationItem(cityName: "Pune", stateName: "Maharashtra", stationCode: "PUNE", stationName: "Pune Junction", isMajorHub: true),
        IndianStationItem(cityName: "Nagpur", stateName: "Maharashtra", stationCode: "NGP", stationName: "Nagpur Junction", isMajorHub: true),
        IndianStationItem(cityName: "Shirdi", stateName: "Maharashtra", stationCode: "SNSI", stationName: "Sainagar Shirdi", isMajorHub: false),
        
        // West Bengal
        IndianStationItem(cityName: "Kolkata (Howrah)", stateName: "West Bengal", stationCode: "HWH", stationName: "Howrah Junction", isMajorHub: true),
        IndianStationItem(cityName: "Kolkata (Sealdah)", stateName: "West Bengal", stationCode: "SDAH", stationName: "Sealdah", isMajorHub: true),
        IndianStationItem(cityName: "Darjeeling / Siliguri", stateName: "West Bengal", stationCode: "NJP", stationName: "New Jalpaiguri Junction", isMajorHub: true),
        
        // Tamil Nadu
        IndianStationItem(cityName: "Chennai Central", stateName: "Tamil Nadu", stationCode: "MAS", stationName: "MGR Chennai Central", isMajorHub: true),
        IndianStationItem(cityName: "Chennai Egmore", stateName: "Tamil Nadu", stationCode: "MS", stationName: "Chennai Egmore", isMajorHub: true),
        IndianStationItem(cityName: "Madurai", stateName: "Tamil Nadu", stationCode: "MDU", stationName: "Madurai Junction", isMajorHub: false),
        IndianStationItem(cityName: "Coimbatore", stateName: "Tamil Nadu", stationCode: "CBE", stationName: "Coimbatore Junction", isMajorHub: false),
        IndianStationItem(cityName: "Kanyakumari", stateName: "Tamil Nadu", stationCode: "CAPE", stationName: "Kanyakumari Terminal", isMajorHub: false),
        
        // Karnataka
        IndianStationItem(cityName: "Bengaluru City", stateName: "Karnataka", stationCode: "SBC", stationName: "KSR Bengaluru City Junction", isMajorHub: true),
        IndianStationItem(cityName: "Bengaluru (Yesvantpur)", stateName: "Karnataka", stationCode: "YPR", stationName: "Yesvantpur Junction", isMajorHub: true),
        IndianStationItem(cityName: "Mysuru", stateName: "Karnataka", stationCode: "MYS", stationName: "Mysuru Junction", isMajorHub: false),
        
        // Himachal Pradesh
        IndianStationItem(cityName: "Shimla", stateName: "Himachal Pradesh", stationCode: "SML", stationName: "Shimla Railway Station", isMajorHub: true),
        IndianStationItem(cityName: "Kalka", stateName: "Himachal Pradesh", stationCode: "KLK", stationName: "Kalka Junction", isMajorHub: true),
        
        // Rajasthan
        IndianStationItem(cityName: "Jaipur", stateName: "Rajasthan", stationCode: "JP", stationName: "Jaipur Junction", isMajorHub: true),
        IndianStationItem(cityName: "Udaipur", stateName: "Rajasthan", stationCode: "UDZ", stationName: "Udaipur City", isMajorHub: false),
        IndianStationItem(cityName: "Jodhpur", stateName: "Rajasthan", stationCode: "JU", stationName: "Jodhpur Junction", isMajorHub: false),
        IndianStationItem(cityName: "Jaisalmer", stateName: "Rajasthan", stationCode: "JSM", stationName: "Jaisalmer Railway Station", isMajorHub: false),
        IndianStationItem(cityName: "Ajmer", stateName: "Rajasthan", stationCode: "AII", stationName: "Ajmer Junction", isMajorHub: false),
        IndianStationItem(cityName: "Kota", stateName: "Rajasthan", stationCode: "KOTA", stationName: "Kota Junction", isMajorHub: false),
        
        // Uttar Pradesh
        IndianStationItem(cityName: "Varanasi", stateName: "Uttar Pradesh", stationCode: "BSB", stationName: "Varanasi Junction", isMajorHub: true),
        IndianStationItem(cityName: "Prayagraj", stateName: "Uttar Pradesh", stationCode: "PRYJ", stationName: "Prayagraj Junction", isMajorHub: true),
        IndianStationItem(cityName: "Lucknow", stateName: "Uttar Pradesh", stationCode: "LKO", stationName: "Lucknow Charbagh", isMajorHub: true),
        IndianStationItem(cityName: "Agra Cantt", stateName: "Uttar Pradesh", stationCode: "AGC", stationName: "Agra Cantt", isMajorHub: true),
        IndianStationItem(cityName: "Ayodhya", stateName: "Uttar Pradesh", stationCode: "AY", stationName: "Ayodhya Dham Junction", isMajorHub: false),
        IndianStationItem(cityName: "Mathura", stateName: "Uttar Pradesh", stationCode: "MTJ", stationName: "Mathura Junction", isMajorHub: false),
        IndianStationItem(cityName: "Gorakhpur", stateName: "Uttar Pradesh", stationCode: "GKP", stationName: "Gorakhpur Junction", isMajorHub: false),
        
        // Kerala
        IndianStationItem(cityName: "Kochi (Ernakulam)", stateName: "Kerala", stationCode: "ERS", stationName: "Ernakulam Junction", isMajorHub: true),
        IndianStationItem(cityName: "Thiruvananthapuram", stateName: "Kerala", stationCode: "TVC", stationName: "Thiruvananthapuram Central", isMajorHub: true),
        IndianStationItem(cityName: "Kozhikode", stateName: "Kerala", stationCode: "CLT", stationName: "Kozhikode Railway Station", isMajorHub: false),
        
        // Goa
        IndianStationItem(cityName: "Goa (Madgaon)", stateName: "Goa", stationCode: "MAO", stationName: "Madgaon Junction", isMajorHub: true),
        IndianStationItem(cityName: "Vasco da Gama", stateName: "Goa", stationCode: "VSG", stationName: "Vasco da Gama", isMajorHub: false),
        
        // Punjab & Chandigarh
        IndianStationItem(cityName: "Chandigarh", stateName: "Punjab & Chandigarh", stationCode: "CDG", stationName: "Chandigarh Junction", isMajorHub: true),
        IndianStationItem(cityName: "Amritsar", stateName: "Punjab & Chandigarh", stationCode: "ASR", stationName: "Amritsar Junction", isMajorHub: true),
        
        // Madhya Pradesh
        IndianStationItem(cityName: "Bhopal", stateName: "Madhya Pradesh", stationCode: "BPL", stationName: "Bhopal Junction", isMajorHub: true),
        IndianStationItem(cityName: "Indore", stateName: "Madhya Pradesh", stationCode: "INDB", stationName: "Indore Junction", isMajorHub: true),
        IndianStationItem(cityName: "Gwalior", stateName: "Madhya Pradesh", stationCode: "GWL", stationName: "Gwalior Junction", isMajorHub: false),
        IndianStationItem(cityName: "Ujjain", stateName: "Madhya Pradesh", stationCode: "UJN", stationName: "Ujjain Junction", isMajorHub: false),
        
        // Odisha
        IndianStationItem(cityName: "Bhubaneswar", stateName: "Odisha", stationCode: "BBS", stationName: "Bhubaneswar Railway Station", isMajorHub: true),
        IndianStationItem(cityName: "Puri", stateName: "Odisha", stationCode: "PURI", stationName: "Puri Terminus", isMajorHub: false),
        
        // Telangana & Andhra Pradesh
        IndianStationItem(cityName: "Hyderabad (Secunderabad)", stateName: "Telangana & AP", stationCode: "SC", stationName: "Secunderabad Junction", isMajorHub: true),
        IndianStationItem(cityName: "Vijayawada", stateName: "Telangana & AP", stationCode: "BZA", stationName: "Vijayawada Junction", isMajorHub: true),
        IndianStationItem(cityName: "Visakhapatnam", stateName: "Telangana & AP", stationCode: "VSKP", stationName: "Visakhapatnam Junction", isMajorHub: true),
        IndianStationItem(cityName: "Tirupati", stateName: "Telangana & AP", stationCode: "TPTY", stationName: "Tirupati Main", isMajorHub: false),
        
        // Jammu & Kashmir
        IndianStationItem(cityName: "Jammu Tawi", stateName: "Jammu & Kashmir", stationCode: "JAT", stationName: "Jammu Tawi", isMajorHub: true),
        IndianStationItem(cityName: "Katra (Vaishno Devi)", stateName: "Jammu & Kashmir", stationCode: "SVDK", stationName: "Shri Mata Vaishno Devi Katra", isMajorHub: false),
        
        // Assam & Northeast
        IndianStationItem(cityName: "Guwahati", stateName: "Assam & Northeast", stationCode: "GHY", stationName: "Guwahati Junction", isMajorHub: true)
    ]
    
    public static var states: [String] {
        Array(Set(stations.map(\.stateName))).sorted()
    }
    
    public static func stations(in state: String) -> [IndianStationItem] {
        stations.filter { $0.stateName == state }
    }
    
    public static func search(query: String) -> [IndianStationItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return stations }
        return stations.filter {
            $0.cityName.lowercased().contains(q) ||
            $0.stateName.lowercased().contains(q) ||
            $0.stationCode.lowercased().contains(q) ||
            $0.stationName.lowercased().contains(q)
        }
    }
}
