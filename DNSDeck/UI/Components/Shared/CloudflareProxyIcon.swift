import SwiftUI

struct CloudflareProxyIcon: View {
    let isProxied: Bool

    var body: some View {
        if isProxied {
            Image("Cloudflare")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .help("Traffic is proxied")
        }
    }
}
