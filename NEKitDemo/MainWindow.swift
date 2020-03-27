//
//  MainWindow.swift
//  NEKitDemo
//
//  Created by ysmo on 2019/12/26.
//  Copyright © 2019 Zhuhao Wang. All rights reserved.
//

import Foundation
import AppKit
import NEKit
import CocoaLumberjackSwift

class MainWindow: NSWindow {
    @IBOutlet weak var txtPassword: NSTextField!
    
     
    @IBOutlet weak var txtUsername: NSTextField!
    @IBOutlet weak var txtSocks5Port: NSTextField!
    @IBOutlet weak var txtHttpPort: NSTextField!
    @IBOutlet weak var btnStatus: NSButton!
    @IBOutlet weak var txtPort: NSTextField!
    @IBOutlet weak var txtServer: NSTextField!
    var runing = false
    
    
   
    var httpProxy: GCDHTTPProxyServer?
    var socks5Proxy: GCDSOCKS5ProxyServer?
    
    
    @IBAction func change_Actopn(_ sender: Any) {
        if(self.runing){
            runing = false
            btnStatus.title = "启动服务"
            
            httpProxy?.stop()
            socks5Proxy?.stop()
        }else{
            self.runing = true
            btnStatus.title = "停止服务"
            
            DDLog.removeAllLoggers()
            DDLog.add(DDTTYLogger.sharedInstance, with: .info)
            
            ObserverFactory.currentFactory = DebugObserverFactory()
            
            let outAdapterFactory = SecureHTTPAdapterFactory (serverHost: txtServer.stringValue, serverPort: txtPort.integerValue, auth: HTTPAuthentication(username: txtUsername.stringValue, password: txtPassword.stringValue))
            
            let allRule = AllRule(adapterFactory: outAdapterFactory)
            var UserRules:[NEKit.Rule] = []
            UserRules.append(contentsOf: [allRule])
            
            let manager = RuleManager(fromRules: UserRules, appendDirect: true)
            
            RuleManager.currentManager = manager
            
            httpProxy = GCDHTTPProxyServer(address: nil, port: NEKit.Port(port: UInt16(txtHttpPort.intValue)))
            try! httpProxy!.start()
            
            
            socks5Proxy = GCDSOCKS5ProxyServer(address: nil, port: NEKit.Port(port: UInt16(txtSocks5Port.intValue)))
            try! socks5Proxy!.start()
        }
        
        
    }
}
