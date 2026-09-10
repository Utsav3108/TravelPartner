import SwiftUI

public struct PriceBreakdownBar: View {
    public let totalBudget: Double
    public let estimatedCost: Double
    public let currency: String
    
    public init(totalBudget: Double, estimatedCost: Double, currency: String = "INR") {
        self.totalBudget = totalBudget
        self.estimatedCost = estimatedCost
        self.currency = currency
    }
    
    private var budgetFraction: Double {
        guard totalBudget > 0 else { return 1.0 }
        return min(1.0, estimatedCost / totalBudget)
    }
    
    private var remainingAmount: Double {
        return totalBudget - estimatedCost
    }
    
    private var isOverBudget: Bool {
        return estimatedCost > totalBudget
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Estimated Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(currency) \(Int(estimatedCost))")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Allocated Budget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(currency) \(Int(totalBudget))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(isOverBudget ? Color.red : (budgetFraction > 0.85 ? Color.orange : Color.green))
                        .frame(width: max(8, geo.size.width * CGFloat(budgetFraction)), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                if isOverBudget {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("\(currency) \(Int(abs(remainingAmount))) over budget")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(currency) \(Int(remainingAmount)) buffer remaining for extra dining & gifts")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(Int(budgetFraction * 100))% utilized")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
