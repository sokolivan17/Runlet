import SwiftUI
import RunnerEngine

enum Formatters {
    static func duration(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.2f s", seconds)
    }

    static func seconds(_ value: Double) -> String { String(format: "%.1f s", value) }

    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}

struct StatusBadge: View {
    let statusCode: Int?

    private var color: Color {
        guard let code = statusCode else { return .red }
        switch code {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text(statusCode.map(String.init) ?? "ERR")
            .font(.caption.monospacedDigit().bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct OutcomeRow: View {
    let outcome: RequestOutcome

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusBadge(statusCode: outcome.statusCode)
            VStack(alignment: .leading, spacing: 2) {
                Text(outcome.name)
                Text("\(outcome.method) · iteration \(outcome.iteration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = outcome.errorDescription {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            Text(Formatters.duration(outcome.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Something went wrong",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
