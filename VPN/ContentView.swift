//
//  ContentView.swift
//  supavpn
//
//  Created by Shahzain Ali on 27/08/2024.
//

import SwiftUI
import NetworkExtension
struct ContentView: View {
    var app: WireguardkitApp
    @State private var vpnStatusText: String = "Status: Unknown"

    var body: some View {
        VStack {
            Text(vpnStatusText)
                .padding()
            
            Button(action: {
                app.turnOnTunnel { isSuccess in
                    print("Tunnel turned on: \(isSuccess)")
                    app.checkTunnelStatus { isConnected in
                        DispatchQueue.main.async {
                            vpnStatusText = isConnected ? "Status: Connected" : "Status: Disconnected"
                        }
                    }
                }
                        }) {
                            Text("Turn On Tunnel")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        // Button to call turnOffTunnel
                        Button(action: {
                            app.turnOffTunnel()
                            vpnStatusText = "Status: Disconnected"
                        }) {
                            Text("Turn Off Tunnel")
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
        }
        .padding()
    }
}

#Preview {
    ContentView(app: WireguardkitApp())
}
