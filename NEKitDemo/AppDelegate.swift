import Cocoa
import NEKit
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var httpProxy: GCDHTTPProxyServer?
    var socks5Proxy: GCDSOCKS5ProxyServer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
//        DDLog.removeAllLoggers()
//        DDLog.add(DDTTYLogger.sharedInstance, with: .info)
//
//        ObserverFactory.currentFactory = DebugObserverFactory()
//
//       let outAdapterFactory = HTTPAdapterFactory(serverHost: "127.0.0.1", serverPort: 1081, auth: nil)
//
//        let allRule = AllRule(adapterFactory: outAdapterFactory)
//        var UserRules:[NEKit.Rule] = []
//        UserRules.append(contentsOf: [allRule])
//
//        let manager = RuleManager(fromRules: UserRules, appendDirect: true)
//
//        RuleManager.currentManager = manager
//
//        httpProxy = GCDHTTPProxyServer(address: nil, port: NEKit.Port(port: UInt16(9090)))
//        try! httpProxy!.start()
//
//
//        socks5Proxy = GCDSOCKS5ProxyServer(address: nil, port: NEKit.Port(port: UInt16(9091)))
//        try! socks5Proxy!.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
//        httpProxy?.stop()
//        socks5Proxy?.stop()
    }

}
