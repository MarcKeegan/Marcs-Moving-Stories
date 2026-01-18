/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds

struct BannerAd: UIViewRepresentable {
    let unitID: String
    
    func makeUIView(context: Context) -> BannerView {
        // User requested width 375 (likely for iPhone width)
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: 375)
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = unitID
        
        // Find the root view controller
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = scene.windows.first?.rootViewController {
            banner.rootViewController = rootViewController
        }
        
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
}
#else
// Fallback if SDK is not installed yet
struct BannerAd: View {
    let unitID: String
    var body: some View {
        Text("AdMob Banner Placeholder")
            .font(.caption)
            .padding()
            .background(Color.gray.opacity(0.2))
    }
}
#endif
