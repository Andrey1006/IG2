import SwiftUI
import WebKit

private let privacyPolicyURL = URL(string: "https://matchbracket.pages.dev/#privacy")!

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("Privacy Policy")
                        .font(.banner(22))
                        .foregroundColor(Turf.chalk)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(ChalkLineButton(compact: true))
                }
                .padding(18)

                ZStack {
                    PolicyPage(url: privacyPolicyURL, attempt: attempt, loading: $loading, failed: $failed)
                        .opacity(failed ? 0 : 1)
                    if loading && !failed {
                        VStack(spacing: 12) {
                            ProgressView().tint(Turf.floodlight).scaleEffect(1.3)
                            Text("Fetching the small print…")
                                .font(.copy(13))
                                .foregroundColor(Turf.haze)
                        }
                    }
                    if failed {
                        EmptyPitch(
                            art: .centreSpot,
                            title: "No signal on this pitch",
                            message: "The policy needs an internet connection. Everything else in Match Bracket works offline.",
                            action: ("Try again", {
                                failed = false
                                loading = true
                                attempt += 1
                            })
                        )
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PolicyPage: UIViewRepresentable {
    let url: URL
    let attempt: Int
    @Binding var loading: Bool
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(loading: $loading, failed: $failed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.showsVerticalScrollIndicator = false
        web.scrollView.showsHorizontalScrollIndicator = false
        context.coordinator.attempt = attempt
        web.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 20))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.loading = $loading
        context.coordinator.failed = $failed
        if context.coordinator.attempt != attempt {
            context.coordinator.attempt = attempt
            web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loading: Binding<Bool>
        var failed: Binding<Bool>
        var attempt = 0

        init(loading: Binding<Bool>, failed: Binding<Bool>) {
            self.loading = loading
            self.failed = failed
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            loading.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loading.wrappedValue = false
            failed.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        private func fail(_ error: Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            loading.wrappedValue = false
            failed.wrappedValue = true
        }
    }
}
