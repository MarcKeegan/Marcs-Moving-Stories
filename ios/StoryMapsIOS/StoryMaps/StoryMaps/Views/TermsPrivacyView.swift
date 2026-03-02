/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import SafariServices

struct TermsPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var safariURL: URL?
    
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
                        url: URL(string: "https://marckeegan.com/storypath/terms/")!
                    ) {
                        safariURL = URL(string: "https://marckeegan.com/storypath/terms/")
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    LegalLinkRow(
                        title: "Privacy Policy",
                        url: URL(string: "https://marckeegan.com/storypath/privacy/")!
                    ) {
                        safariURL = URL(string: "https://marckeegan.com/storypath/privacy/")
                    }
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
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.preferredControlTintColor = UIColor(red: 0.23, green: 0.16, blue: 0.25, alpha: 1.0)
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// Make URL conform to Identifiable for sheet presentation
extension URL: Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Legal Link Row

struct LegalLinkRow: View {
    let title: String
    let url: URL
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
