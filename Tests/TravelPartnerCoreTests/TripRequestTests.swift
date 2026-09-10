import Testing
import Foundation
@testable import TravelPartnerCore

struct TripRequestTests {
    
    @Test("Valid TripRequest initializes and passes validation")
    func testValidTripRequest() throws {
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 5,
            travelersCount: 4,
            groupType: .friends,
            budget: 50000.0,
            currency: "INR",
            tripType: .roundTrip,
            preferences: [.nature, .relaxation]
        )
        
        #expect(throws: Never.self) {
            try request.validate()
        }
        
        #expect(request.budgetPerTraveler == 12500.0)
        #expect(request.budgetPerDay == 10000.0)
        #expect(request.destination == "Shimla")
        #expect(request.origin == "Delhi")
        #expect(request.numberOfDays == 5)
        #expect(request.travelersCount == 4)
    }
    
    @Test("TripRequest validation rejects empty destination")
    func testEmptyDestination() {
        let request = TripRequest(
            origin: "Delhi",
            destination: "   ",
            numberOfDays: 5,
            travelersCount: 2,
            budget: 30000.0
        )
        
        #expect(throws: TripRequestValidationError.emptyDestination) {
            try request.validate()
        }
    }
    
    @Test("TripRequest validation rejects empty origin")
    func testEmptyOrigin() {
        let request = TripRequest(
            origin: "",
            destination: "Goa",
            numberOfDays: 3,
            travelersCount: 2,
            budget: 20000.0
        )
        
        #expect(throws: TripRequestValidationError.emptyOrigin) {
            try request.validate()
        }
    }
    
    @Test("TripRequest validation rejects insufficient budget")
    func testInsufficientBudget() {
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 5,
            travelersCount: 4,
            budget: 500.0,
            currency: "INR"
        )
        
        #expect(throws: TripRequestValidationError.insufficientBudget(500.0, "INR")) {
            try request.validate()
        }
    }
}
