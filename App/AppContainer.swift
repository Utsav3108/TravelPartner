import Foundation

/// Lightweight Dependency Injection Container.
///
/// **Architectural Role:**
/// Decouples SwiftUI Views and ViewModels from concrete infrastructure implementations.
/// Allows swapping between production Firebase/Gemini/Live providers and in-memory mock providers
/// for unit tests, Xcode SwiftUI previews, and offline operation without global singletons.
public final class AppContainer: @unchecked Sendable {
    public static let shared = AppContainer()
    
    // Repositories
    public let tripRepository: TripRepositoryProtocol
    public let userRepository: UserRepositoryProtocol
    public let feedbackRepository: FeedbackRepositoryProtocol
    
    // Live Search Providers
    public let flightSearchProvider: FlightSearchProviderProtocol
    public let trainSearchProvider: TrainSearchProviderProtocol
    public let hotelSearchProvider: HotelSearchProviderProtocol
    public let placeSearchProvider: PlaceSearchProviderProtocol
    public let weatherSearchProvider: WeatherSearchProviderProtocol
    public let travelSearchService: TravelSearchServiceProtocol
    
    // Domain & Engine Services
    public let constraintEngine: ConstraintEngineProtocol
    public let recommendationEngine: RecommendationEngineProtocol
    public let itineraryOptimizer: ItineraryOptimizerProtocol
    public let geminiService: GeminiServiceProtocol
    public let tripPlanningService: TripPlanningCoordinator
    
    public init(
        tripRepository: TripRepositoryProtocol = FirebaseTripRepository(),
        userRepository: UserRepositoryProtocol = LocalFirebaseEmulatedRepository.shared,
        feedbackRepository: FeedbackRepositoryProtocol = LocalFirebaseEmulatedRepository.shared,
        flightSearchProvider: FlightSearchProviderProtocol = MockFlightSearchProvider(),
        trainSearchProvider: TrainSearchProviderProtocol = MockTrainSearchProvider(),
        hotelSearchProvider: HotelSearchProviderProtocol = MockHotelSearchProvider(),
        placeSearchProvider: PlaceSearchProviderProtocol = MockPlaceSearchProvider(),
        weatherSearchProvider: WeatherSearchProviderProtocol = MockWeatherSearchProvider(),
        travelSearchService: TravelSearchServiceProtocol? = nil,
        constraintEngine: ConstraintEngineProtocol = ConstraintEngine(),
        recommendationEngine: RecommendationEngineProtocol? = nil,
        itineraryOptimizer: ItineraryOptimizerProtocol = ItineraryOptimizer(),
        geminiService: GeminiServiceProtocol = HybridGeminiService()
    ) {
        self.tripRepository = tripRepository
        self.userRepository = userRepository
        self.feedbackRepository = feedbackRepository
        
        self.flightSearchProvider = flightSearchProvider
        self.trainSearchProvider = trainSearchProvider
        self.hotelSearchProvider = hotelSearchProvider
        self.placeSearchProvider = placeSearchProvider
        self.weatherSearchProvider = weatherSearchProvider
        
        let searchService = travelSearchService ?? LiveTravelSearchService(
            flightProvider: flightSearchProvider,
            trainProvider: trainSearchProvider,
            hotelProvider: hotelSearchProvider,
            placeProvider: placeSearchProvider,
            weatherProvider: weatherSearchProvider
        )
        self.travelSearchService = searchService
        
        self.constraintEngine = constraintEngine
        let mlEngine = recommendationEngine ?? CoreMLRecommendationEngine(feedbackRepository: feedbackRepository)
        self.recommendationEngine = mlEngine
        self.itineraryOptimizer = itineraryOptimizer
        self.geminiService = geminiService
        
        self.tripPlanningService = TripPlanningCoordinator(
            travelSearchService: searchService,
            constraintEngine: constraintEngine,
            recommendationEngine: mlEngine,
            itineraryOptimizer: itineraryOptimizer,
            geminiService: geminiService,
            tripRepository: tripRepository
        )
    }
    
    /// Pre-configured mock container ideal for SwiftUI previews and hermetic unit tests.
    public static var mock: AppContainer {
        let emulatedRepo = LocalFirebaseEmulatedRepository(useDiskPersistence: false)
        return AppContainer(
            tripRepository: emulatedRepo,
            userRepository: emulatedRepo,
            feedbackRepository: emulatedRepo,
            recommendationEngine: DeterministicRankingEngine(),
            geminiService: FallbackGeminiService()
        )
    }
}
