import SwiftUI
import SwiftData
import UserNotifications

@Observable
final class DeeplinkRouter {
    var pendingSOPId: UUID?
}

@main
struct SOPifyApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegateIOS.self) private var appDelegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegateMac.self) private var appDelegate
    #endif

    let container: ModelContainer = {
        let schema = Schema([SOP.self, Step.self, ExecutionRecord.self, StepCompletion.self, Category.self, BranchOption.self, Trigger.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let url = config.url
            let related = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
            for file in related {
                try? FileManager.default.removeItem(at: file)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to construct ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.deeplinkRouter)
        }
        .modelContainer(container)
    }
}

// MARK: - iOS App Delegate

#if os(iOS)
class AppDelegateIOS: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let deeplinkRouter = DeeplinkRouter()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let sopIdString = userInfo["sopId"] as? String,
           let sopId = UUID(uuidString: sopIdString) {
            await MainActor.run {
                deeplinkRouter.pendingSOPId = sopId
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
#endif

// MARK: - macOS App Delegate

#if os(macOS)
class AppDelegateMac: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let deeplinkRouter = DeeplinkRouter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let sopIdString = userInfo["sopId"] as? String,
           let sopId = UUID(uuidString: sopIdString) {
            await MainActor.run {
                deeplinkRouter.pendingSOPId = sopId
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
#endif
