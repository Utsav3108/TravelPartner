import SwiftUI

public struct FreshnessBadgeView: View {
    public let metadata: CandidateMetadata
    
    public init(metadata: CandidateMetadata) {
        self.metadata = metadata
    }
    
    public var body: some View {
        if !metadata.isFareVerified {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
                Text("Unverified Fare")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(metadata.isFresh ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                
                Text(metadata.isFresh ? (metadata.isMock ? "Real-Time (Verified)" : "Live Verified") : "Revalidate Required")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(metadata.isFresh ? .secondary : .orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
            )
        }
    }
}
