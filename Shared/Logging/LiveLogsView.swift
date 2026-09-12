import SwiftUI

/// Live, searchable developer console sheet rendering real-time API, Core ML, and Gemini activity.
public struct LiveLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [LogEntry] = []
    @State private var selectedCategory: LogCategory? = nil
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true
    @State private var observerId: UUID? = nil
    @State private var expandedLogId: UUID? = nil
    @State private var showShareSheet: Bool = false
    @State private var exportedText: String = ""
    
    public init() {}
    
    public var filteredLogs: [LogEntry] {
        logs.filter { entry in
            if let cat = selectedCategory, entry.category != cat {
                return false
            }
            if let lvl = selectedLevel, entry.level != lvl {
                return false
            }
            if !searchText.isEmpty {
                let matchMsg = entry.message.localizedCaseInsensitiveContains(searchText)
                let matchDetails = entry.details?.localizedCaseInsensitiveContains(searchText) ?? false
                return matchMsg || matchDetails
            }
            return true
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Metric Counters Header
                metricHeader
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Filters Bar
                filtersBar
                    .padding(.vertical, 8)
                
                Divider()
                
                // Log Entries Stream
                if filteredLogs.isEmpty {
                    emptyState
                } else {
                    logsList
                }
            }
            .searchable(text: $searchText, prompt: "Filter by endpoint, model, prompt, error...")
            .navigationTitle("Activity & AI Logs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            exportedText = AppLogger.shared.exportLogsAsString()
                            showShareSheet = true
                        }) {
                            Label("Export Logs", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: {
                            AppLogger.shared.clearLogs()
                            logs.removeAll()
                        }) {
                            Label("Clear All Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                #if os(iOS)
                ShareSheet(items: [exportedText])
                #else
                ScrollView {
                    Text(exportedText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                }
                .frame(minWidth: 400, minHeight: 300)
                #endif
            }
            .onAppear {
                logs = AppLogger.shared.recentLogs(limit: 500)
                observerId = AppLogger.shared.observe { newEntry in
                    Task { @MainActor in
                        logs.append(newEntry)
                        if logs.count > 500 {
                            logs.removeFirst(logs.count - 500)
                        }
                    }
                }
            }
            .onDisappear {
                if let id = observerId {
                    AppLogger.shared.removeObserver(id: id)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var metricHeader: some View {
        HStack(spacing: 12) {
            statBadge(
                emoji: "🌐",
                title: "API",
                count: logs.filter { $0.category == .api }.count,
                color: .blue
            )
            statBadge(
                emoji: "🧠",
                title: "CoreML",
                count: logs.filter { $0.category == .coreML }.count,
                color: .purple
            )
            statBadge(
                emoji: "✨",
                title: "Gemini",
                count: logs.filter { $0.category == .gemini }.count,
                color: .indigo
            )
            statBadge(
                emoji: "❌",
                title: "Errors",
                count: logs.filter { $0.level == .error }.count,
                color: .red
            )
        }
    }
    
    private func statBadge(emoji: String, title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption2)
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }
    
    private var filtersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All Subsystems", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                
                ForEach(LogCategory.allCases, id: \.self) { cat in
                    filterChip(title: "\(cat.emoji) \(cat.rawValue)", isSelected: selectedCategory == cat) {
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(14)
        }
    }
    
    private var logsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredLogs) { entry in
                    logRow(for: entry)
                        .id(entry.id)
                }
            }
            .listStyle(.plain)
        }
    }
    
    private func logRow(for entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(entry.category.emoji)
                    .font(.caption)
                
                Text(entry.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                badge(for: entry.level)
                
                if let dur = entry.formattedDuration {
                    Text(dur)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            Text(entry.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if let details = entry.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(expandedLogId == entry.id ? nil : 2)
                    .padding(.top, 2)
                
                Button(expandedLogId == entry.id ? "Show less" : "Show full details") {
                    withAnimation {
                        expandedLogId = (expandedLogId == entry.id) ? nil : entry.id
                    }
                }
                .font(.caption2)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func badge(for level: LogLevel) -> some View {
        let (color, text): (Color, String) = {
            switch level {
            case .debug: return (.gray, "DEBUG")
            case .info: return (.blue, "INFO")
            case .success: return (.green, "SUCCESS")
            case .warning: return (.orange, "WARN")
            case .error: return (.red, "ERROR")
            }
        }()
        
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .cornerRadius(4)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No Logs Recorded Yet")
                .font(.headline)
            Text("API network calls, Core ML inference metrics, and Gemini generations will stream here in real time.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#if os(iOS)
// MARK: - Share Sheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
