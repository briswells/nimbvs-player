import Foundation
import Network

@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private(set) var isConnected = true
    private(set) var isExpensive = false
    private(set) var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Check if downloads are allowed given current network and user preferences
    func canDownload(allowCellular: Bool) -> Bool {
        guard isConnected else { return false }
        if isExpensive && !allowCellular { return false }
        return true
    }
}
