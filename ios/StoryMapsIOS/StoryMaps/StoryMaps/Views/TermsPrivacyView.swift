/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct TermsPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 34/255, green: 30/255, blue: 35/255)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Back Button
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Terms & Privacy")
                            .font(.googleSansBody)
                    }
                    .foregroundColor(.white)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Header
                Text("Legal")
                    .font(.googleSans(size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.bottom, 24)
                
                // Legal Links
                VStack(spacing: 0) {
                    LegalLinkRow(
                        title: "Terms of Service",
                        url: URL(string: "https://storypath.app/terms")!
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    LegalLinkRow(
                        title: "Privacy Policy",
                        url: URL(string: "https://storypath.app/privacy")!
                    )
                }
                
                Spacer()
                
                // Version Info
                VStack(spacing: 8) {
                    Text("StoryPath")
                        .font(.googleSansBody)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.googleSansCaption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Legal Link Row

struct LegalLinkRow: View {
    let title: String
    let url: URL
    
    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(.googleSansBody)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    NavigationStack {
        TermsPrivacyView()
    }
}
