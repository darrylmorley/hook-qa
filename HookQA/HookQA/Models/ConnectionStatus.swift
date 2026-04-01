import Foundation

enum ConnectionStatus: Sendable, Equatable {
    case connected(Int)   // model count
    case unreachable
    case checking
}

extension ConnectionStatus {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .connected(let count):
            return "\(count) model\(count == 1 ? "" : "s")"
        case .unreachable:
            return "Unreachable"
        case .checking:
            return "Checking…"
        }
    }
}
