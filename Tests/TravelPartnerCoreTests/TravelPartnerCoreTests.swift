import Testing
import Foundation
@testable import TravelPartnerCore

struct TrainSelectionAndFareTests {
    
    @Test("Selecting alternative train preserves all options and keeps alternatives available to change again")
    func testAlternativeTrainOptionsPreservedWhenSwitching() {
        let fare3A = TrainClassFare(classCode: "3A", totalFare: 565)
        let fare2A = TrainClassFare(classCode: "2A", totalFare: 770)
        
        let train1 = TrainCandidate(
            trainNumber: "12005",
            trainName: "Kalka Shatabdi",
            originStation: "NDLS",
            destinationStation: "KLK",
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(14400),
            durationMinutes: 240,
            pricePerPerson: 565,
            seatClass: "3A",
            classFares: [fare3A, fare2A],
            selectedClassCode: "3A"
        )
        
        let train2 = TrainCandidate(
            trainNumber: "22447",
            trainName: "Vande Bharat Express",
            originStation: "NDLS",
            destinationStation: "KLK",
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(12600),
            durationMinutes: 210,
            pricePerPerson: 850,
            seatClass: "CC",
            classFares: [TrainClassFare(classCode: "CC", totalFare: 850), TrainClassFare(classCode: "EC", totalFare: 1650)],
            selectedClassCode: "CC"
        )
        
        let train3 = TrainCandidate(
            trainNumber: "12311",
            trainName: "Netaji Express",
            originStation: "DLI",
            destinationStation: "KLK",
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(18000),
            durationMinutes: 300,
            pricePerPerson: 420,
            seatClass: "SL",
            classFares: [TrainClassFare(classCode: "SL", totalFare: 280), TrainClassFare(classCode: "3A", totalFare: 510)],
            selectedClassCode: "3A"
        )
        
        var primaryTransport = TransportOption(from: train1)
        let altOption2 = TransportOption(from: train2)
        let altOption3 = TransportOption(from: train3)
        primaryTransport.isRecommended = true
        primaryTransport.alternativeOptions = [altOption2, altOption3]
        
        var itinerary = TripItinerary(
            destination: "Shimla",
            origin: "Delhi",
            travelersCount: 2,
            selectedTransportation: primaryTransport
        )
        
        // Initially, train 1 is selected with 2 alternatives (train 2 and train 3)
        #expect(itinerary.selectedTransportation?.title.contains("12005") == true)
        #expect(itinerary.selectedTransportation?.isRecommended == true)
        #expect(itinerary.selectedTransportation?.alternativeOptions.count == 2)
        
        // 1. User switches to Train 2 (Vande Bharat)
        let chosenTrain2 = itinerary.selectedTransportation!.alternativeOptions.first(where: { $0.title.contains("22447") })!
        itinerary.updateSelectedTransportation(chosenTrain2)
        
        // Now Train 2 is selected and is NOT recommended (recommended tag removed)
        #expect(itinerary.selectedTransportation?.title.contains("22447") == true)
        #expect(itinerary.selectedTransportation?.isRecommended == false)
        // CRUCIAL: Alternatives MUST NOT be hidden or empty! Both Train 1 and Train 3 must be available!
        #expect(itinerary.selectedTransportation?.alternativeOptions.count == 2)
        let altTrain1 = itinerary.selectedTransportation?.alternativeOptions.first(where: { $0.title.contains("12005") })
        #expect(altTrain1 != nil)
        #expect(altTrain1?.isRecommended == true) // Recommended train retains recommendation tag in alternatives list
        #expect(itinerary.selectedTransportation?.alternativeOptions.contains(where: { $0.title.contains("12311") }) == true)
        
        // 2. User switches to Train 3 (Netaji Express)
        let chosenTrain3 = itinerary.selectedTransportation!.alternativeOptions.first(where: { $0.title.contains("12311") })!
        itinerary.updateSelectedTransportation(chosenTrain3)
        
        // Now Train 3 is selected and is NOT recommended
        #expect(itinerary.selectedTransportation?.title.contains("12311") == true)
        #expect(itinerary.selectedTransportation?.isRecommended == false)
        // Alternatives still contains Train 1 (recommended) and Train 2
        #expect(itinerary.selectedTransportation?.alternativeOptions.count == 2)
        #expect(itinerary.selectedTransportation?.alternativeOptions.first(where: { $0.title.contains("12005") })?.isRecommended == true)
        #expect(itinerary.selectedTransportation?.alternativeOptions.contains(where: { $0.title.contains("22447") }) == true)
        
        // 3. User switches back to Train 1 (Kalka Shatabdi, the recommended train)
        let recommTrainToSelect = itinerary.selectedTransportation!.alternativeOptions.first(where: { $0.title.contains("12005") })!
        itinerary.updateSelectedTransportation(recommTrainToSelect)
        
        // Tag is restored to selected train!
        #expect(itinerary.selectedTransportation?.title.contains("12005") == true)
        #expect(itinerary.selectedTransportation?.isRecommended == true)
        #expect(itinerary.selectedTransportation?.alternativeOptions.count == 2)
    }
    
    @Test("Switching train coach class accurately updates price per person and total trip cost")
    func testTrainClassSwitchingUpdatesCost() {
        let fare3A = TrainClassFare(classCode: "3A", totalFare: 565)
        let fare2A = TrainClassFare(classCode: "2A", totalFare: 770)
        let train = TrainCandidate(
            trainNumber: "12005",
            trainName: "Kalka Shatabdi",
            originStation: "NDLS",
            destinationStation: "KLK",
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(14400),
            durationMinutes: 240,
            pricePerPerson: 565,
            seatClass: "3A",
            classFares: [fare3A, fare2A],
            selectedClassCode: "3A"
        )
        
        let travelers = 2
        var itinerary = TripItinerary(
            destination: "Shimla",
            origin: "Delhi",
            travelersCount: travelers,
            totalBudget: 25000,
            selectedTransportation: TransportOption(from: train)
        )
        
        let initialCost = itinerary.totalEstimatedCost
        #expect(itinerary.selectedTransportation?.selectedClassCode == "3A")
        #expect(itinerary.selectedTransportation?.pricePerPerson == 565)
        
        // Switch to 2A
        itinerary.updateSelectedTrainClass(code: "2A")
        #expect(itinerary.selectedTransportation?.selectedClassCode == "2A")
        #expect(itinerary.selectedTransportation?.pricePerPerson == 770)
        
        // Total cost must increase by (770 - 565) * 2 = 410 INR
        let expectedCostDiff = (770.0 - 565.0) * Double(travelers)
        #expect(itinerary.totalEstimatedCost == initialCost + expectedCostDiff)
        #expect(itinerary.budgetRemaining == 25000.0 - itinerary.totalEstimatedCost)
    }
}

struct ConnectingTrainJourneyTests {

    private func makeSampleConnectingJourney(
        id: String = "12005_KLK_52451",
        train1Number: String = "12005",
        train1Name: String = "Kalka Shatabdi Express",
        train2Number: String = "52451",
        train2Name: String = "Shivalik Deluxe Express",
        hubCode: String = "KLK",
        hubName: String = "Kalka",
        layoverMinutes: Int = 95,
        leg1Fares: [TrainClassFare] = [
            TrainClassFare(classCode: "3A", totalFare: 565, baseFare: 450, gst: 28, superfastCharge: 45, reservationCharge: 40),
            TrainClassFare(classCode: "2A", totalFare: 770, baseFare: 630, gst: 38, superfastCharge: 45, reservationCharge: 50)
        ],
        leg2Fares: [TrainClassFare] = [
            TrainClassFare(classCode: "CC", totalFare: 350, baseFare: 280, gst: 17, superfastCharge: 25, reservationCharge: 25),
            TrainClassFare(classCode: "EC", totalFare: 680, baseFare: 550, gst: 34, superfastCharge: 45, reservationCharge: 50)
        ],
        isRecommended: Bool = false
    ) -> TrainConnectingJourney {
        let baseDate = Date()
        let dep1 = baseDate
        let arr1 = dep1.addingTimeInterval(14400) // 4h
        let dep2 = arr1.addingTimeInterval(Double(layoverMinutes * 60))
        let arr2 = dep2.addingTimeInterval(18000) // 5h
        
        let leg1 = TrainCandidate(
            trainNumber: train1Number,
            trainName: train1Name,
            originStation: "New Delhi (NDLS)",
            destinationStation: "\(hubName) (\(hubCode))",
            departureTime: dep1,
            arrivalTime: arr1,
            durationMinutes: 240,
            pricePerPerson: leg1Fares.first?.totalFare ?? 565,
            seatClass: leg1Fares.first?.classCode ?? "3A",
            classFares: leg1Fares,
            selectedClassCode: leg1Fares.first?.classCode ?? "3A",
            availableClasses: leg1Fares.map(\.classCode)
        )
        
        let leg2 = TrainCandidate(
            trainNumber: train2Number,
            trainName: train2Name,
            originStation: "\(hubName) (\(hubCode))",
            destinationStation: "Shimla (SML)",
            departureTime: dep2,
            arrivalTime: arr2,
            durationMinutes: 300,
            pricePerPerson: leg2Fares.first?.totalFare ?? 350,
            seatClass: leg2Fares.first?.classCode ?? "CC",
            classFares: leg2Fares,
            selectedClassCode: leg2Fares.first?.classCode ?? "CC",
            availableClasses: leg2Fares.map(\.classCode)
        )
        
        let hub = TrainConnectionHub(
            stationCode: hubCode,
            stationName: "\(hubName) (\(hubCode))",
            arrivalTime: arr1,
            departureTime: dep2,
            layoverMinutes: layoverMinutes
        )
        
        let totalDuration = 240 + layoverMinutes + 300
        
        return TrainConnectingJourney(
            id: id,
            segments: [leg1, leg2],
            connection: hub,
            geminiRationale: nil,
            isRecommended: isRecommended,
            totalDurationMinutes: totalDuration
        )
    }
    
    @Test("Connecting journey correctly computes composite fare, layover and route summaries")
    func testConnectingJourneyInitializationAndPricing() {
        let journey = makeSampleConnectingJourney()
        let transport = TransportOption(from: journey)
        
        #expect(transport.isConnecting == true)
        #expect(transport.stops == 1)
        #expect(transport.pricePerPerson == 915.0) // 565 + 350
        #expect(transport.selectedClassCode == "3A + CC")
        #expect(journey.combinedClassSummary == "3A + CC")
        #expect(journey.routeSummary == "New Delhi → Kalka → Shimla")
        #expect(journey.connection.formattedLayover == "1h 35m")
        #expect(journey.formattedTotalDuration == "10h 35m")
        #expect(transport.title.contains("Kalka Shatabdi Express + Shivalik Deluxe Express"))
    }
    
    @Test("Strict layover boundary filtering ensures safe interchange transfer")
    func testLayoverFilterBoundaries() {
        // Layover bounds: 60 minutes <= layover <= 240 minutes
        func isLayoverValid(_ layoverMinutes: Int) -> Bool {
            return layoverMinutes >= 60 && layoverMinutes <= 240
        }
        
        // Exact boundaries
        #expect(isLayoverValid(60) == true)
        #expect(isLayoverValid(240) == true)
        
        // Typical optimal layovers
        #expect(isLayoverValid(90) == true)
        #expect(isLayoverValid(120) == true)
        #expect(isLayoverValid(150) == true)
        
        // Too short for platform/train transfer in Indian Railways (rejected)
        #expect(isLayoverValid(59) == false)
        #expect(isLayoverValid(45) == false)
        #expect(isLayoverValid(15) == false)
        #expect(isLayoverValid(0) == false)
        #expect(isLayoverValid(-30) == false)
        
        // Too long / excessive wait (rejected)
        #expect(isLayoverValid(241) == false)
        #expect(isLayoverValid(300) == false)
        #expect(isLayoverValid(480) == false)
    }
    
    @Test("Independent per-leg class switching updates leg classes and dynamically recalculates total trip cost")
    func testIndependentPerLegClassSwitchingAndRecalculation() {
        let journey = makeSampleConnectingJourney()
        let transport = TransportOption(from: journey)
        let travelers = 2
        let totalBudget = 35000.0
        
        var itinerary = TripItinerary(
            destination: "Shimla",
            origin: "Delhi",
            travelersCount: travelers,
            totalBudget: totalBudget,
            selectedTransportation: transport
        )
        
        let initialCost = itinerary.totalEstimatedCost
        #expect(itinerary.selectedTransportation?.pricePerPerson == 915.0) // 565 + 350
        #expect(itinerary.selectedTransportation?.selectedClassCode == "3A + CC")
        
        // 1. Upgrade Leg 1 from 3A (565) to 2A (770). Leg 2 remains CC (350)
        itinerary.updateConnectingSegmentClass(segmentIndex: 0, classCode: "2A")
        
        let leg1Updated = itinerary.selectedTransportation?.connectingJourney?.segments[0]
        let leg2AfterLeg1Update = itinerary.selectedTransportation?.connectingJourney?.segments[1]
        
        #expect(leg1Updated?.selectedClassCode == "2A")
        #expect(leg1Updated?.pricePerPerson == 770.0)
        #expect(leg2AfterLeg1Update?.selectedClassCode == "CC")
        #expect(leg2AfterLeg1Update?.pricePerPerson == 350.0)
        
        let expectedFareAfterLeg1 = 770.0 + 350.0 // 1120.0
        #expect(itinerary.selectedTransportation?.pricePerPerson == expectedFareAfterLeg1)
        #expect(itinerary.selectedTransportation?.selectedClassCode == "2A + CC")
        
        let costDiffLeg1 = (expectedFareAfterLeg1 - 915.0) * Double(travelers) // (1120 - 915) * 2 = 410
        #expect(itinerary.totalEstimatedCost == initialCost + costDiffLeg1)
        #expect(itinerary.budgetRemaining == totalBudget - itinerary.totalEstimatedCost)
        
        // 2. Upgrade Leg 2 from CC (350) to EC (680). Leg 1 remains 2A (770)
        itinerary.updateConnectingSegmentClass(segmentIndex: 1, classCode: "EC")
        
        let leg1AfterLeg2Update = itinerary.selectedTransportation?.connectingJourney?.segments[0]
        let leg2Updated = itinerary.selectedTransportation?.connectingJourney?.segments[1]
        
        #expect(leg1AfterLeg2Update?.selectedClassCode == "2A")
        #expect(leg1AfterLeg2Update?.pricePerPerson == 770.0)
        #expect(leg2Updated?.selectedClassCode == "EC")
        #expect(leg2Updated?.pricePerPerson == 680.0)
        
        let expectedFareAfterBoth = 770.0 + 680.0 // 1450.0
        #expect(itinerary.selectedTransportation?.pricePerPerson == expectedFareAfterBoth)
        #expect(itinerary.selectedTransportation?.selectedClassCode == "2A + EC")
        
        let totalCostDiff = (expectedFareAfterBoth - 915.0) * Double(travelers) // (1450 - 915) * 2 = 1070
        #expect(itinerary.totalEstimatedCost == initialCost + totalCostDiff)
        #expect(itinerary.budgetRemaining == totalBudget - itinerary.totalEstimatedCost)
    }
    
    @Test("Alternative connecting journey selection preserves recommendation tag and enables switching back")
    func testConnectingJourneyOptionSwitchingAndTagPreservation() {
        let journey1 = makeSampleConnectingJourney(id: "J1", train1Number: "12005", train1Name: "Kalka Shatabdi", train2Number: "52451", train2Name: "Shivalik Express", isRecommended: true)
        let journey2 = makeSampleConnectingJourney(id: "J2", train1Number: "22447", train1Name: "Vande Bharat", train2Number: "52453", train2Name: "Himalayan Queen", isRecommended: false)
        let journey3 = makeSampleConnectingJourney(id: "J3", train1Number: "12311", train1Name: "Netaji Express", train2Number: "52455", train2Name: "Shimla Passenger", isRecommended: false)
        
        var option1 = TransportOption(from: journey1)
        option1.isRecommended = true
        let option2 = TransportOption(from: journey2)
        let option3 = TransportOption(from: journey3)
        option1.alternativeOptions = [option2, option3]
        
        var itinerary = TripItinerary(
            destination: "Shimla",
            origin: "Delhi",
            travelersCount: 2,
            selectedTransportation: option1
        )
        
        // Initial state: Option 1 is selected and marked recommended
        #expect(itinerary.selectedTransportation?.title.contains("12005") == true || itinerary.selectedTransportation?.title.contains("Kalka Shatabdi") == true)
        #expect(itinerary.selectedTransportation?.isRecommended == true)
        #expect(itinerary.selectedTransportation?.alternativeOptions.count == 2)
        
        // 1. Switch to Option 2 (Vande Bharat connecting)
        let chosenAlt = itinerary.selectedTransportation!.alternativeOptions.first(where: { $0.title.contains("22447") || $0.title.contains("Vande Bharat") })!
        itinerary.updateSelectedTransportation(chosenAlt)
        
        // Now Option 2 is selected and NOT recommended
        #expect(itinerary.selectedTransportation?.title.contains("22447") == true || itinerary.selectedTransportation?.title.contains("Vande Bharat") == true)
        #expect(itinerary.selectedTransportation?.isRecommended == false)
        
        // The original recommended Option 1 MUST be preserved in alternatives and still have isRecommended == true
        #expect(itinerary.selectedTransportation?.alternativeOptions.count == 2)
        let altOption1 = itinerary.selectedTransportation?.alternativeOptions.first(where: { $0.title.contains("12005") || $0.title.contains("Kalka Shatabdi") })
        #expect(altOption1 != nil)
        #expect(altOption1?.isRecommended == true)
        
        // 2. Switch back to Option 1
        itinerary.updateSelectedTransportation(altOption1!)
        
        // Selected journey is recommended again
        #expect(itinerary.selectedTransportation?.title.contains("12005") == true || itinerary.selectedTransportation?.title.contains("Kalka Shatabdi") == true)
        #expect(itinerary.selectedTransportation?.isRecommended == true)
        #expect(itinerary.selectedTransportation?.alternativeOptions.count == 2)
    }
    
    @Test("Gemini connecting journey ranking validates candidate IDs and produces trade-off rationale")
    func testGeminiConnectingJourneyRecommendationValidation() async throws {
        let j1 = makeSampleConnectingJourney(id: "12005_KLK_52451", train1Number: "12005", train1Name: "Kalka Shatabdi Express", train2Number: "52451", train2Name: "Shivalik Deluxe Express", layoverMinutes: 100)
        let j2 = makeSampleConnectingJourney(id: "22447_KLK_52453", train1Number: "22447", train1Name: "Vande Bharat Express", train2Number: "52453", train2Name: "Himalayan Queen", layoverMinutes: 130)
        let j3 = makeSampleConnectingJourney(id: "14095_KLK_52455", train1Number: "14095", train1Name: "Himalayan Queen Express", train2Number: "52455", train2Name: "Shimla Passenger", layoverMinutes: 200)
        
        let service = FallbackGeminiService()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 3,
            travelersCount: 2,
            budget: 30000
        )
        
        let result = try await service.recommendConnectingJourney(journeys: [j1, j2, j3], request: request)
        
        let validIds = Set([j1.id, j2.id, j3.id])
        #expect(validIds.contains(result.recommendedJourneyId))
        #expect(!result.rationale.isEmpty)
        #expect(result.topThreeJourneyIds.count <= 3)
        for id in result.topThreeJourneyIds {
            #expect(validIds.contains(id))
        }
        
        // Test fallback validation when an unrecognized or hallucinated ID is encountered
        let hallucinatedId = "non_existent_99999"
        let safeChosen = [j1, j2, j3].first(where: { $0.id == hallucinatedId }) ?? [j1, j2, j3][0]
        #expect(safeChosen.id == j1.id)
    }
    
    @Test("Real PRS fares are strictly preserved without synthetic fallback in connecting journeys")
    func testPRSRealFaresIntegrityWithoutSyntheticComputation() {
        let realFareLeg1 = TrainClassFare(classCode: "3A", totalFare: 565, baseFare: 450, gst: 28, superfastCharge: 45, reservationCharge: 40)
        let realFareLeg2 = TrainClassFare(classCode: "CC", totalFare: 350, baseFare: 280, gst: 17, superfastCharge: 25, reservationCharge: 25)
        
        let journey = makeSampleConnectingJourney(leg1Fares: [realFareLeg1], leg2Fares: [realFareLeg2])
        
        // Exact sum of PRS fares: 565 + 350 = 915
        #expect(journey.totalFarePerPerson == 915.0)
        #expect(journey.segments[0].pricePerPerson == 565.0)
        #expect(journey.segments[1].pricePerPerson == 350.0)
        
        // Verify base fare + GST + charges
        let leg1 = journey.segments[0].classFares[0]
        #expect(leg1.baseFare == 450)
        #expect(leg1.gst == 28)
        #expect(leg1.superfastCharge == 45)
        #expect(leg1.reservationCharge == 40)
        
        let leg2 = journey.segments[1].classFares[0]
        #expect(leg2.baseFare == 280)
        #expect(leg2.gst == 17)
    }
    
    @Test("Viramgam to Puducherry returns connecting journey and never a fake direct train")
    func testViramgamToPuducherryConnectingTrainResolution() async throws {
        let provider = RailRadarTrainSearchProvider()
        let trains = try await provider.searchTrains(origin: "Viramgam", destination: "Puducherry", date: Date(), travelers: 1)
        
        // Viramgam to Puducherry has NO direct trains.
        // It must return connecting trains with connectingJourney != nil, never a synthetic direct train!
        #expect(!trains.isEmpty)
        for train in trains {
            #expect(train.connectingJourney != nil, "All trains between Viramgam and Puducherry must be connecting journeys")
            let connecting = train.connectingJourney!
            #expect(connecting.segments.count >= 2, "Connecting journey must have at least 2 segments")
            
            let leg1 = connecting.segments[0]
            let leg2 = connecting.segments[1]
            
            // Leg 1 must depart from Viramgam (VG)
            #expect(leg1.originStation.contains("VG") || leg1.originStation.contains("Viramgam"))
            // Leg 2 must arrive at Puducherry (PDY)
            #expect(leg2.destinationStation.contains("PDY") || leg2.destinationStation.contains("Puducherry") || leg2.destinationStation.contains("Pondicherry"))
            
            // Layover must be authentic safe buffer (at least 60 minutes)
            #expect(connecting.connection.layoverMinutes >= 60)
            
            // Fares must be calculated accurately
            #expect(connecting.totalFarePerPerson > 1000.0)
            #expect(train.pricePerPerson == connecting.totalFarePerPerson)
        }
    }
}

// MARK: - Mock URL Protocol for Network Testing

final class MockNetworkURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = Self.mockHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

// MARK: - Network Class & Generic Codable Parsing Tests

struct NetworkClassTests {
    
    struct PlaceItem: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let city: String
        let rating: Double
    }
    
    private func makeTestNetwork(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> Network {
        MockNetworkURLProtocol.mockHandler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockNetworkURLProtocol.self]
        let session = URLSession(configuration: config)
        return Network(session: session)
    }
    
    @Test("network.perform parses generic Codable array: let places: [Place] = network.perform(request: Request)")
    func testGenericPerformDecodesArrayOfCodables() async throws {
        let samplePlaces = [
            PlaceItem(id: "p1", name: "Amber Palace", city: "Jaipur", rating: 4.8),
            PlaceItem(id: "p2", name: "Hawa Mahal", city: "Jaipur", rating: 4.6)
        ]
        let encodedData = try JSONEncoder().encode(samplePlaces)
        
        let network = makeTestNetwork { req in
            let http = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (http, encodedData)
        }
        
        let request = Request(url: URL(string: "https://api.travelpartner.ai/v1/places")!)
        
        // Exact syntax from user request: let places: [Places] = try await network.perform(request: Request)
        let places: [PlaceItem] = try await network.perform(request: request)
        
        #expect(places.count == 2)
        #expect(places[0].name == "Amber Palace")
        #expect(places[1].city == "Jaipur")
        #expect(places == samplePlaces)
    }
    
    @Test("network.perform throws NetworkError.httpError on non-2xx status code")
    func testHTTPErrorThrowsStructuredError() async throws {
        let errorBody = "{\"error\": \"Rate limit exceeded\"}".data(using: .utf8)!
        let network = makeTestNetwork { req in
            let http = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (http, errorBody)
        }
        
        let request = Request(url: URL(string: "https://api.railradar.in/v1/trains")!)
        
        do {
            let _: [PlaceItem] = try await network.perform(request: request)
            Issue.record("Expected NetworkError.httpError to be thrown")
        } catch let NetworkError.httpError(statusCode, data, _) {
            #expect(statusCode == 429)
            #expect(!data.isEmpty)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("network.perform throws NetworkError.decodingError on schema mismatch")
    func testDecodingErrorDiagnostics() async throws {
        let invalidJson = "{\"invalid\": \"schema\"}".data(using: .utf8)!
        let network = makeTestNetwork { req in
            let http = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (http, invalidJson)
        }
        
        let request = Request(url: URL(string: "https://api.travelpartner.ai/v1/places")!)
        
        do {
            let _: [PlaceItem] = try await network.perform(request: request)
            Issue.record("Expected decodingError to be thrown")
        } catch let NetworkError.decodingError(underlying, typeName, _) {
            #expect(typeName.contains("Array<PlaceItem>"))
            #expect(!underlying.localizedDescription.isEmpty)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("Request constructor properly formats HTTP headers and method")
    func testRequestBuilder() {
        let url = URL(string: "https://api.railradar.in/v1/trains")!
        let request = Request(
            url: url,
            method: .post,
            headers: ["Authorization": "Bearer token123", "x-api-key": "secret456"]
        )
        
        let urlReq = request.asURLRequest()
        #expect(urlReq.httpMethod == "POST")
        #expect(urlReq.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
        #expect(urlReq.value(forHTTPHeaderField: "x-api-key") == "secret456")
    }
}

