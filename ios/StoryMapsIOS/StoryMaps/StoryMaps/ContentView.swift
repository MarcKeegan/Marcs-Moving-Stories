/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isLoading {
                LoadingView()
            } else if authViewModel.currentUser != nil {
                StoryMapsMainView()
            } else {
                AuthView()
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.94)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "map.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                
                Text("Checking your session...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .preferredColorScheme(.light) // Force light mode for consistent UI design
    }
}
