
import SwiftUI
import WebKit

struct FeatureView: View {
    let targetUrl: String
    
    var body: some View {
        NavigationView {
            ContentContainer(targetUrl: targetUrl)
                .navigationBarHidden(true)
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color.black.ignoresSafeArea(.all))
    }
}

struct ContentContainer: View {
    let targetUrl: String
    @State private var webView = WKWebView()
    @State private var canGoBack = false
    @State private var canGoForward = false
    @AppStorage("gate") var point: String = ""
    @AppStorage("locked") var locked: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ContentWrapper(
                webView: $webView,
                targetUrl: targetUrl,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                point: $point,
                locked: $locked
            )
            
            HStack {
                Spacer()
                
                Button(action: {
                    if webView.canGoBack { webView.goBack() }
                }) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                
                Spacer()
                
                Button(action: {
                    if webView.canGoForward { webView.goForward() }
                }) {
                    Image(systemName: "chevron.forward")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                
                Spacer()
            }
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea(.all))
    }
}

struct ContentWrapper: UIViewRepresentable {
    @Binding var webView: WKWebView
    let targetUrl: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var point: String
    @Binding var locked: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let wk = WKWebView(frame: .zero, configuration: config)
        wk.navigationDelegate = context.coordinator
        wk.uiDelegate = context.coordinator
        let osVersion = UIDevice.current.systemVersion
        let osUA = osVersion.replacingOccurrences(of: ".", with: "_")
        wk.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS \(osUA) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(osVersion) Mobile/15E148 Safari/604.1"
        guard let url = URL(string: targetUrl), UIApplication.shared.canOpenURL(url) else {
            return wk
        }
        wk.load(URLRequest(url: url))
        wk.allowsBackForwardNavigationGestures = true

        DispatchQueue.main.async {
            self.webView = wk
        }

        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ContentWrapper
        
        init(_ parent: ContentWrapper) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                
                if let url = webView.url?.absoluteString, !self.parent.locked {
                    self.parent.locked = true
                    self.parent.point = url
                }
            }
        }
        
        @available(iOS 15, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
        
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

