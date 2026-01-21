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
            Color(red: 34/255, green: 30/255, blue: 35/255)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 40)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.9))
                
                Text("Checking your session...")
                    .font(.googleSansSubheadline)
                    .foregroundColor(.secondary)
            }
        }
        .preferredColorScheme(.dark) // Force light mode for consistent UI design
    }
}
