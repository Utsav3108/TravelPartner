import SwiftUI

public struct RationaleCardView: View {
    public let rationale: RecommendationRationale
    
    public init(rationale: RecommendationRationale) {
        self.rationale = rationale
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.indigo)
                
                Text("Recommended because:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.indigo)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rationale.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.top, 2)
                        
                        Text(bullet)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.indigo.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
        )
    }
}
