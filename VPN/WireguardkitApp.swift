//
//  WireguardkitApp.swift
//  Wireguardkit
//
//  Created by Shahzain Ali on 27/08/2024.
//

import SwiftUI
import NetworkExtension

@main
struct WireguardkitApp: App {
    
    // NOTE: This MUST exactly match the Network Extension target's Bundle ID.
    // Ensure the main app's Bundle ID is a prefix of this!
    private let extensionBundleIdentifier = "com.resistine.integrated.vpn.mac.network-extension" // REPLACE THIS
    
    // Keep a reference to the manager to ensure notifications work
    // Keep a reference to the manager to ensure notifications work
    static private var tunnelManager: NETunnelProviderManager?
    static private var statusObserver: Any?
    
    var body: some Scene {
        WindowGroup {
            ContentView(app: self)
        }
    }
    
    // ... (turnOnTunnel and turnOffTunnel remain mostly the same but should use the retained manager if possible) ...
    
    // MARK: - Turn ON Tunnel
    
    func turnOnTunnel(completionHandler: @escaping (Bool) -> Void) {
        NSLog("--- START: Attempting to turn ON tunnel ---")
        
        // 1. Load existing preferences to check if a manager exists
        NETunnelProviderManager.loadAllFromPreferences { tunnelManagersInSettings, error in
            
            if let error = error {
                NSLog("ERROR [1. Load]: loadAllFromPreferences failed: \(error.localizedDescription)")
                completionHandler(false)
                return
            }
            
            // Use existing manager or create a new one
            let preExistingTunnelManager = tunnelManagersInSettings?.first
            let manager = preExistingTunnelManager ?? NETunnelProviderManager()
            WireguardkitApp.tunnelManager = manager // Retain it
            
            if preExistingTunnelManager != nil {
                NSLog("STATUS [1. Load]: Existing tunnel manager found and loaded.")
            } else {
                NSLog("STATUS [1. Load]: Creating NEW tunnel manager instance.")
            }

            // 2. Configure the custom VPN protocol
            let protocolConfiguration = NETunnelProviderProtocol()

            // Set the tunnel extension's bundle id
            protocolConfiguration.providerBundleIdentifier = self.extensionBundleIdentifier
            protocolConfiguration.serverAddress = "WireGuard Server"
            
            // --- WireGuard Configuration ---
            // REPLACE THIS WITH YOUR CONFIGURATION
            let wgQuickConfig = """
            [Interface]
            
            """
            
            // 3. Log the specific configuration details
            NSLog("CONFIG INFO: Tunnel will be configured with:")
            NSLog("  > Provider Bundle ID: \(self.extensionBundleIdentifier)")
            
            protocolConfiguration.providerConfiguration = [
                "wgQuickConfig": wgQuickConfig
            ]

            manager.protocolConfiguration = protocolConfiguration
            manager.localizedDescription = "Resistine VPN Tunnel"
            manager.isEnabled = true

            // 4. Save the tunnel to preferences (requires user auth if new)
            manager.saveToPreferences { error in
                
                if let error = error {
                    NSLog("ERROR [2. Save]: saveToPreferences failed: \(error.localizedDescription)")
                    completionHandler(false)
                    return
                }
                NSLog("STATUS [2. Save]: Tunnel manager successfully saved to system preferences.")
                
                // 5. Reload the manager to get a usable session instance
                manager.loadFromPreferences { error in
                    
                    if let error = error {
                        NSLog("ERROR [3. Reload]: loadFromPreferences after save failed: \(error.localizedDescription)")
                        completionHandler(false)
                        return
                    }
                    NSLog("STATUS [3. Reload]: Tunnel manager successfully reloaded.")

                    // 6. Attempt to start the tunnel session
                    do {
                        NSLog("ACTION [4. Start]: Attempting to start tunnel session...")
                        guard let session = manager.connection as? NETunnelProviderSession else {
                            // This should not happen if the target is set up correctly
                            NSLog("FATAL ERROR [4. Start]: connection is invalid (Not NETunnelProviderSession).")
                            completionHandler(false)
                            return
                        }
                        
                        // START MONITORING STATUS CHANGES
                        // We already have a global monitor, but we can ensure it's hooked up here too
                        self.setupStatusObserver(for: session)
                        
                        try session.startTunnel()
                        NSLog("SUCCESS [4. Start]: startTunnel called. Waiting for extension to execute...")
                    } catch {
                        // This catch block handles system errors (e.g., system preventing launch)
                        NSLog("ERROR [4. Start]: startTunnel failed: \(error.localizedDescription)")
                        completionHandler(false)
                    }
                    completionHandler(true)
                }
            }
        }
    }
    
    // MARK: - Turn OFF Tunnel
    
    func turnOffTunnel() {
        NSLog("--- START: Attempting to turn OFF tunnel ---")
        
        // Use retained manager if available, otherwise load
        if let manager = WireguardkitApp.tunnelManager {
            self.stopTunnel(manager: manager)
        } else {
            NETunnelProviderManager.loadAllFromPreferences { tunnelManagersInSettings, error in
                if let error = error {
                    NSLog("ERROR [OFF Load]: loadAllFromPreferences failed: \(error.localizedDescription)")
                    return
                }
                if let manager = tunnelManagersInSettings?.first {
                    WireguardkitApp.tunnelManager = manager
                    self.stopTunnel(manager: manager)
                } else {
                    NSLog("STATUS [OFF Stop]: No tunnel manager found to stop.")
                }
            }
        }
    }
    
    private func stopTunnel(manager: NETunnelProviderManager) {
        guard let session = manager.connection as? NETunnelProviderSession else {
            NSLog("FATAL ERROR [OFF Stop]: tunnelManager.connection is invalid")
            return
        }
        
        NSLog("STATUS [OFF Check]: Tunnel status is: \(session.status)")
        
        switch session.status {
        case .connected, .connecting, .reasserting:
            NSLog("ACTION [OFF Stop]: Stopping the tunnel session.")
            session.stopTunnel()
        case .disconnected, .invalid:
            NSLog("STATUS [OFF Stop]: Tunnel is already disconnected or invalid. No action taken.")
        case .disconnecting: break
        @unknown default:
            NSLog("STATUS [OFF Stop]: Tunnel is in an unknown state. No action taken.")
            break
        }
    }
    
    // MARK: - Check Tunnel Status
    
    func checkTunnelStatus(completionHandler: @escaping (Bool) -> Void) {
        // Always reload from preferences to get the latest status from the system
        NETunnelProviderManager.loadAllFromPreferences { tunnelManagersInSettings, error in
            if let error = error {
                NSLog("ERROR [Check Status]: loadAllFromPreferences failed: \(error.localizedDescription)")
                completionHandler(false)
                return
            }
            
            guard let manager = tunnelManagersInSettings?.first else {
                NSLog("STATUS [Check Status]: No tunnel manager found.")
                completionHandler(false)
                return
            }
            
            self.setupStatusObserver(for: manager.connection as! NETunnelProviderSession) // Ensure observing
            WireguardkitApp.tunnelManager = manager // Update retained manager
            
            let status = manager.connection.status
            NSLog("STATUS [Check Status]: Current status is \(status)")
            
            switch status {
            case .connected, .connecting, .reasserting:
                completionHandler(true)
            default:
                completionHandler(false)
            }
        }
    }
    
    // MARK: - Status Monitoring
    
    func startMonitoringStatus() {
        checkTunnelStatus { _ in } // This will load the manager and setup the observer
    }
    
    private func setupStatusObserver(for session: NETunnelProviderSession) {
        // Remove existing observer to avoid duplicates
        if let observer = WireguardkitApp.statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Add new observer and store the token
        WireguardkitApp.statusObserver = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: session, queue: .main) { notification in
            guard let session = notification.object as? NETunnelProviderSession else { return }
            let status = session.status
            NSLog("VPN STATUS CHANGE [Monitor]: \(status)")
            
            let isConnected: Bool
            switch status {
            case .connected, .connecting, .reasserting:
                isConnected = true
            default:
                isConnected = false
            }
            
            NotificationCenter.default.post(name: Notification.Name("VPNStatusDidChange"), object: nil, userInfo: ["isConnected": isConnected])
        }
    }
    
    init() {
        startMonitoringStatus()
    }
}

// MARK: - Helper Extension for Logging
// Allows us to print the NEVPNStatus (inherited by NETunnelProviderSession) easily.

// MARK: - Helper Extension for Logging

// Extend the base NEVPNStatus enum, which NETunnelProviderSession.Status uses.
extension NEVPNStatus: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid: return "Invalid"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting"
        case .disconnected: return "Disconnected"
        case .reasserting: return "Reasserting"
        @unknown default: return "Unknown (\(self.rawValue))"
        }
    }
}
