import SwiftUI

public struct FreshnessBadgeView: View {
    public let metadata: CandidateMetadata
    
    public init(metadata: CandidateMetadata) {
        self.metadata = metadata
    }
    
    public var body: some View {
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
