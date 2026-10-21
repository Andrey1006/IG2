
import SwiftUI
import OneSignalFramework
import AppsFlyerLib
import AppTrackingTransparency
import FirebaseCore

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?
    private var pushid = UUID().uuidString
    private var askedForPush = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        OneSignal.initialize("b8699a74-62f5-47dc-8003-8a91d83d7aed", withLaunchOptions: launchOptions)

        let id = UserDefaults.standard.string(forKey: "pushid")
        if id == nil {
            UserDefaults.standard.set(pushid, forKey: "pushid")
            OneSignal.login(pushid)
        } else {
            pushid = id!
        }

        let window = UIWindow()
        window.rootViewController = UIHostingController(rootView: StartView())
        window.overrideUserInterfaceStyle = .dark
        self.window = window
        window.makeKeyAndVisible()

        AppsFlyerLib.shared().initialize(devKey: "4q6xs5Qn3PNYxQH7fmggGk", appId: "6822788500")
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { _ in
                    AppsFlyerLib.shared().start()
                    DispatchQueue.main.async { self.askForPush() }
                }
            } else {
                AppsFlyerLib.shared().start()
                self.askForPush()
            }
        }
    }

    private func askForPush() {
        guard !askedForPush else { return }
        askedForPush = true
        OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: false)
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let dict = conversionInfo.reduce(into: [String: Any]()) { result, item in
            if let key = item.key as? String { result[key] = item.value }
        }

        let status = dict["af_status"] as? String ?? ""

        if status == "Organic" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.fetchConversionDataByAPI()
            }
        } else {
            self.saveConversionData(dict)
        }
    }

    private func saveConversionData(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            UserDefaults.standard.setValue(data, forKey: "conversionInfo")
            UserDefaults.standard.setValue(true, forKey: "recieved")
        }
    }

    private func fetchConversionDataByAPI() {
        let devKey = AppsFlyerLib.shared().appsFlyerDevKey
        let appleAppID = AppsFlyerLib.shared().appleAppID
        let afUID = AppsFlyerLib.shared().getAppsFlyerUID()

        let urlString = "https://api2.appsflyer.com/inappevent/\(appleAppID)?devkey=\(devKey)&device_id=\(afUID)"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    self.saveConversionData(json)
                }
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.setValue(true, forKey: "recieved")
                }
            }
        }.resume()
    }

    func onConversionDataFail(_ error: Error) {
        UserDefaults.standard.setValue("", forKey: "conversionInfo")
        UserDefaults.standard.setValue(true, forKey: "recieved")
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        let dict = attributionData.reduce(into: [String: Any]()) { result, item in
            if let key = item.key as? String { result[key] = item.value }
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            UserDefaults.standard.setValue(data, forKey: "conversionInfo")
        }
        UserDefaults.standard.setValue(true, forKey: "recieved")
    }

    func onAppOpenAttributionFailure(_ error: Error) {
        UserDefaults.standard.setValue(true, forKey: "recieved")
    }
}
