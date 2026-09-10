import Foundation
import SwiftUI

@Observable
@MainActor
public final class TripWizardViewModel {
    public var currentStep: Int = 1
    public let totalSteps: Int = 4
    
    // Step 1: Route & Dates
    public var origin: String = "Delhi"
    public var destination: String = "Shimla"
    public var startDate: Date = Date()
    public var numberOfDays: Int = 5
    
    // Step 2: Group & Direction
    public var travelersCount: Int = 4
    public var groupType: GroupType = .friends
    public var tripType: TripType = .roundTrip
    
    // Step 3: Budget
    public var budget: Double = 50000.0
    public var currency: String = "INR"
    
    // Step 4: Personalization Preferences
    public var selectedPreferences: Set<TravelPreference> = [.nature, .relaxation, .adventure]
    public var pace: PacePreference = .moderate
    public var dietary: DietaryPreference = .none
    public var customNotes: String = ""
    
    public var validationError: String? = nil
    
    public init() {}
    
    public init(from request: TripRequest) {
        self.origin = request.origin
        self.destination = request.destination
        self.startDate = request.startDate
        self.numberOfDays = request.numberOfDays
        self.travelersCount = request.travelersCount
        self.groupType = request.groupType
        self.tripType = request.tripType
        self.budget = request.budget
        self.currency = request.currency
        self.selectedPreferences = request.preferences
        self.pace = request.pace
        self.dietary = request.dietary
        self.customNotes = request.customNotes ?? ""
    }
    
    // MARK: - Navigation
    
    public func nextStep() -> Bool {
        validationError = nil
        if currentStep == 1 {
            if destination.trimmingCharacters(in: .whitespaces).isEmpty {
                validationError = "Please enter a destination."
                return false
            }
            if origin.trimmingCharacters(in: .whitespaces).isEmpty {
                validationError = "Please enter your starting origin."
                return false
            }
        } else if currentStep == 3 {
            if budget < 1000 {
                validationError = "Please enter a realistic budget for \(numberOfDays) days."
                return false
            }
        }
        
        if currentStep < totalSteps {
            currentStep += 1
            return false
        }
        return true // Reached final step
    }
    
    public func previousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
    }
    
    public func togglePreference(_ pref: TravelPreference) {
        if selectedPreferences.contains(pref) {
            if selectedPreferences.count > 1 {
                selectedPreferences.remove(pref)
            }
        } else {
            selectedPreferences.insert(pref)
        }
    }
    
    public var budgetPerTraveler: Double {
        return travelersCount > 0 ? budget / Double(travelersCount) : budget
    }
    
    public var budgetPerDay: Double {
        return numberOfDays > 0 ? budget / Double(numberOfDays) : budget
    }
    
    public func buildTripRequest() throws -> TripRequest {
        let request = TripRequest(
            origin: origin,
            destination: destination,
            startDate: startDate,
            numberOfDays: numberOfDays,
            travelersCount: travelersCount,
            groupType: groupType,
            budget: budget,
            currency: currency,
            tripType: tripType,
            preferences: selectedPreferences,
            pace: pace,
            dietary: dietary,
            customNotes: customNotes.isEmpty ? nil : customNotes
        )
        try request.validate()
        return request
    }
}
