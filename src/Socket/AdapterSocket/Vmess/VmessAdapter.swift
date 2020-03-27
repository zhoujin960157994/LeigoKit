//
//  VmessAdapter.swift
//  NEKit
//
//  Created by wfei on 2020/2/8.
//  Copyright © 2020 Zhuhao Wang. All rights reserved.
//

import Foundation


public class VmessAdapter: AdapterSocket {
    let uuid: UUID
    var vmessSession: VmessSession?
    
    let serverHost: String
    let serverPort: Int
    let path: String
    let alterId: Int
    
    public init(serverHost: String, serverPort: Int, uuid: UUID,alterId: Int,path: String) {
        self.uuid = uuid
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.path = path
        self.alterId = alterId
        super.init()
    }
    
    override public func openSocketWith(session: ConnectSession) {
        super.openSocketWith(session: session)
        
        guard !isCancelled else {
            return
        }
        
        let tlsSettings:[String: AnyObject] = ["path":path as AnyObject,"alterId": alterId as AnyObject]
        do {
            try socket.connectTo(host: self.serverHost, port: self.serverPort, enableTLS: false, tlsSettings: tlsSettings)
        } catch {}
        
        var auth = VmessAuth(uuid: self.uuid)
        
        var command: VmessCommand
        if session.isIP() {
            command = VmessCommand(ip: IPAddress(fromString: session.host)!, port: UInt16(session.port))
        } else {
            command = VmessCommand(domain: session.host, port: UInt16(session.port))
        }
        
        self.vmessSession = VmessSession(auth: &auth, command: &command)
    }
    
    override public func didConnectWith(socket: RawTCPSocketProtocol) {
        self.socket.write(data: (self.vmessSession?.packReqHeader())!)
        
        super.didConnectWith(socket: socket)
        delegate?.didBecomeReadyToForwardWith(socket: self)
    }
    
    override public func didRead(data: Data, from rawSocket: RawTCPSocketProtocol) {
        var decryptData: Data?
        
        self.vmessSession!.handleResp(respData: data)
        while let udata = self.vmessSession!.unpackResp() {
            decryptData = udata
            super.didRead(data: udata, from: rawSocket)
            delegate?.didRead(data: udata, from: self)
        }
        
        if decryptData == nil {
            super.didRead(data: Data(), from: rawSocket)
            delegate?.didRead(data: Data(), from: self)
        }
    }
    
    override public func didWrite(data: Data?, by rawSocket: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: rawSocket)
        delegate?.didWrite(data: data, by: self)
    }
    
    override public func readData() {
        super.socket.readData()
    }
    
    override public func write(data: Data) {
        guard !self.isCancelled && self.vmessSession != nil else {
            return
        }
        
        self.socket.write(data: self.vmessSession!.packReq(bodyData: data))
    }
    
    override public func disconnect(becauseOf error: Error? = nil) {
        self.socket.write(data: self.vmessSession!.terminateReq())
        super.disconnect(becauseOf: error)
    }
    
    override public func forceDisconnect(becauseOf error: Error? = nil) {
        super.forceDisconnect(becauseOf: error)
    }
}
