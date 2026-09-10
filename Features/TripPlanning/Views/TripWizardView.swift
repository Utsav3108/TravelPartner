import SwiftUI

public struct TripWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TripWizardViewModel
    public var onComplete: (TripRequest) -> Void
    
    public init(initialRequest: TripRequest? = nil, onComplete: @escaping (TripRequest) -> Void) {
        if let initial = initialRequest {
            _viewModel = State(initialValue: TripWizardViewModel(from: initial))
        } else {
            _viewModel = State(initialValue: TripWizardViewModel())
        }
        self.onComplete = onComplete
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step Progress Bar
                HStack(spacing: 6) {
                    ForEach(1...viewModel.totalSteps, id: \.self) { step in
                        Capsule()
                            .fill(step <= viewModel.currentStep ? Color.blue : Color.secondary.opacity(0.2))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Group {
                            switch viewModel.currentStep {
                            case 1:
                                stepOneRouteAndDates
                            case 2:
                                stepTwoTravelersAndGroup
                            case 3:
                                stepThreeBudget
                            case 4:
                                stepFourPreferences
                            default:
                                EmptyView()
                            }
                        }
                        
                        if let err = viewModel.validationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                }
                
                // Bottom Action Bar
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        if viewModel.currentStep > 1 {
                            Button {
                                viewModel.previousStep()
                            } label: {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            if viewModel.nextStep() {
                                do {
                                    let req = try viewModel.buildTripRequest()
                                    onComplete(req)
                                    dismiss()
                                } catch {
                                    viewModel.validationError = error.localizedDescription
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.currentStep == viewModel.totalSteps ? "Generate Trip Plan" : "Next")
                                    .fontWeight(.bold)
                                Image(systemName: viewModel.currentStep == viewModel.totalSteps ? "sparkles" : "chevron.right")
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color.secondary.opacity(0.05))
            }
            .navigationTitle("Custom Trip Planner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Destination & Dates
    
    @ViewBuilder
    private var stepOneRouteAndDates: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Step 1 of 4")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("Where & When")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Specify your destination, starting city, and journey duration.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Destination City")
                    .font(.caption)
                    .fontWeight(.semibold)
                TextField("e.g. Shimla, Manali, Goa", text: $viewModel.destination)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Starting Origin")
                    .font(.caption)
                    .fontWeight(.semibold)
                TextField("e.g. Delhi, Mumbai, Chandigarh", text: $viewModel.origin)
                    .textFieldStyle(.roundedBorder)
            }
            
            DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                .datePickerStyle(.compact)
            
            Stepper(value: $viewModel.numberOfDays, in: 1...30) {
                HStack {
                    Text("Duration:")
                    Text("\(viewModel.numberOfDays) \(viewModel.numberOfDays == 1 ? "day" : "days")")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Step 2: Travelers & Group Type
    
    @ViewBuilder
    private var stepTwoTravelersAndGroup: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Step 2 of 4")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("Who is Traveling?")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Accommodation capacity and activity safety adapt to your group dynamic.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Stepper(value: $viewModel.travelersCount, in: 1...25) {
                HStack {
                    Text("Number of Travelers:")
                    Text("\(viewModel.travelersCount)")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Group Type")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(GroupType.allCases, id: \.self) { type in
                        Button {
                            viewModel.groupType = type
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: type.iconName)
                                    .foregroundColor(viewModel.groupType == type ? .blue : .secondary)
                                Text(type.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(viewModel.groupType == type ? .bold : .regular)
                                    .foregroundColor(viewModel.groupType == type ? .primary : .secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.groupType == type ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.groupType == type ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Journey Type")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Picker("Trip Type", selection: $viewModel.tripType) {
                    ForEach(TripType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - Step 3: Budget
    
    @ViewBuilder
    private var stepThreeBudget: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Step 3 of 4")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("Total Budget")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Deterministic business rules enforce your ceiling across transport, rooms, and meals.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField("50000", value: $viewModel.budget, format: .number)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                
                Picker("Currency", selection: $viewModel.currency) {
                    Text("INR (₹)").tag("INR")
                    Text("USD ($)").tag("USD")
                    Text("EUR (€)").tag("EUR")
                }
                .pickerStyle(.menu)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
            
            // Quick Breakdown Cards
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Per Traveler")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.currency) \(Int(viewModel.budgetPerTraveler))")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Per Day (Total Group)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.currency) \(Int(viewModel.budgetPerDay))")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
            }
        }
    }
    
    // MARK: - Step 4: Personalization Preferences
    
    @ViewBuilder
    private var stepFourPreferences: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Step 4 of 4")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("Travel Preferences & Pace")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Features evaluated on-device via Core ML for personalized attraction scoring.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Interests (Tap to toggle)")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(TravelPreference.allCases, id: \.self) { pref in
                        let isSelected = viewModel.selectedPreferences.contains(pref)
                        Button {
                            viewModel.togglePreference(pref)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: pref.iconName)
                                    .foregroundColor(isSelected ? .blue : .secondary)
                                Text(pref.rawValue)
                                    .font(.caption)
                                    .fontWeight(isSelected ? .bold : .regular)
                                    .foregroundColor(isSelected ? .primary : .secondary)
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Pacing")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Picker("Pace", selection: $viewModel.pace) {
                    ForEach(PacePreference.allCases, id: \.self) { p in
                        Text("\(p.rawValue) (~\(p.maxActivitiesPerDay)/day)").tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Dietary Preferences")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Picker("Diet", selection: $viewModel.dietary) {
                    ForEach(DietaryPreference.allCases, id: \.self) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}
