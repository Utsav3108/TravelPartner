import SwiftUI

public struct PlanningProgressView: View {
    @State private var viewModel = TripPlanningViewModel()
    public let request: TripRequest
    public var onComplete: (TripItinerary) -> Void
    public var onCancel: () -> Void
    
    public init(
        request: TripRequest,
        onComplete: @escaping (TripItinerary) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.request = request
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Animated Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                        .frame(width: 110, height: 110)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(viewModel.currentProgress.progressFraction))
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.35), value: viewModel.currentProgress.progressFraction)
                    
                    Image(systemName: viewModel.currentProgress.stage.iconName)
                        .font(.system(size: 38))
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Text Headlines
                VStack(spacing: 8) {
                    Text(viewModel.currentProgress.headline)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let sub = viewModel.currentProgress.subhead {
                        Text(sub)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Pipeline Milestones Tracker
                VStack(alignment: .leading, spacing: 10) {
                    let displayStages: [PlanningStage] = [
                        .searchingLiveTravel,
                        .applyingConstraints,
                        .rankingPersonalization,
                        .optimizingItinerary,
                        .generatingNarrative,
                        .savingTrip
                    ]
                    
                    ForEach(displayStages, id: \.self) { stage in
                        let isDone = viewModel.completedStages.contains(stage)
                        let isCurrent = viewModel.currentProgress.stage == stage
                        
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isDone ? Color.green : (isCurrent ? Color.blue : Color.secondary.opacity(0.2)))
                                    .frame(width: 22, height: 22)
                                
                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                } else if isCurrent {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            Text(stage.rawValue)
                                .font(.subheadline)
                                .fontWeight(isCurrent ? .bold : .regular)
                                .foregroundColor(isDone ? .primary : (isCurrent ? .blue : .secondary))
                            
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                // Error Alert if any
                if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        Button("Retry Planning") {
                            viewModel.startPlanning(request: request)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Cancel Button
                Button {
                    viewModel.cancel()
                    onCancel()
                } label: {
                    Text("Cancel Planning")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("AI Planning Engine")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.cancel()
                        onCancel()
                    }
                }
            }
            .task {
                viewModel.startPlanning(request: request)
            }
            .onChange(of: viewModel.generatedItinerary) { _, newItinerary in
                if let itinerary = newItinerary {
                    onComplete(itinerary)
                }
            }
        }
    }
}
