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
    private let extensionBundleIdentifier = ""
    
    var body: some Scene {
        WindowGroup {
            ContentView(app: self)
        }
    }
    
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
            let tunnelManager = preExistingTunnelManager ?? NETunnelProviderManager()
            
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
            let wgQuickConfig = """
            
            """
            
            // 3. Log the specific configuration details
            NSLog("CONFIG INFO: Tunnel will be configured with:")
            NSLog("  > Provider Bundle ID: \(self.extensionBundleIdentifier)")
            NSLog("  > Server Endpoint: 18.199.109.145:986")
            NSLog("  > Client Address: 10.49.64.211/32")
            NSLog("  > Tunnel Name: Resistine VPN Tunnel")

            protocolConfiguration.providerConfiguration = [
                "wgQuickConfig": wgQuickConfig
            ]

            tunnelManager.protocolConfiguration = protocolConfiguration
            tunnelManager.localizedDescription = "Resistine VPN Tunnel"
            tunnelManager.isEnabled = true

            // 4. Save the tunnel to preferences (requires user auth if new)
            tunnelManager.saveToPreferences { error in
                
                if let error = error {
                    NSLog("ERROR [2. Save]: saveToPreferences failed: \(error.localizedDescription)")
                    completionHandler(false)
                    return
                }
                NSLog("STATUS [2. Save]: Tunnel manager successfully saved to system preferences.")
                
                // 5. Reload the manager to get a usable session instance
                tunnelManager.loadFromPreferences { error in
                    
                    if let error = error {
                        NSLog("ERROR [3. Reload]: loadFromPreferences after save failed: \(error.localizedDescription)")
                        completionHandler(false)
                        return
                    }
                    NSLog("STATUS [3. Reload]: Tunnel manager successfully reloaded.")

                    // 6. Attempt to start the tunnel session
                    do {
                        NSLog("ACTION [4. Start]: Attempting to start tunnel session...")
                        guard let session = tunnelManager.connection as? NETunnelProviderSession else {
                            // This should not happen if the target is set up correctly
                            NSLog("FATAL ERROR [4. Start]: connection is invalid (Not NETunnelProviderSession).")
                            completionHandler(false)
                            return
                        }
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
        
        // 1. Load existing preferences to find the tunnel manager
        NETunnelProviderManager.loadAllFromPreferences { tunnelManagersInSettings, error in
            
            if let error = error {
                NSLog("ERROR [OFF Load]: loadAllFromPreferences failed: \(error.localizedDescription)")
                return
            }
            
            // Get the first (and only) tunnel configuration for this app
            if let tunnelManager = tunnelManagersInSettings?.first {
                
                guard let session = tunnelManager.connection as? NETunnelProviderSession else {
                    NSLog("FATAL ERROR [OFF Stop]: tunnelManager.connection is invalid")
                    return
                }
                
                // Log current status before deciding to stop
                NSLog("STATUS [OFF Check]: Tunnel status is: \(session.status as any CustomStringConvertible as CustomStringConvertible)")
                
                // Only stop if the tunnel is currently active or trying to connect
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
            } else {
                NSLog("STATUS [OFF Stop]: No tunnel manager found to stop.")
            }
        }
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
