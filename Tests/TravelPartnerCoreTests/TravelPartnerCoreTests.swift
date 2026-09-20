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
