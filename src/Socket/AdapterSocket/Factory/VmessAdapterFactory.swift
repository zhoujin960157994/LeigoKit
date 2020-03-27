//
//  VmessAdapterFactory.swift
//  NEKit
//
//  Created by wfei on 2020/2/9.
//  Copyright © 2020 Zhuhao Wang. All rights reserved.
//

import Foundation

/// Factory building Vmess adapter.
open class VmessAdapterFactory: ServerAdapterFactory {
    let uuid: UUID
    let path: String
    let alterId:Int
    public init(serverHost: String, serverPort: Int, uuid: UUID,alterId: Int,path: String) {
        self.uuid = uuid
        self.path = path
        self.alterId = alterId
        super.init(serverHost: serverHost, serverPort: serverPort)
    }

    /**
     Get a SOCKS5 adapter.

     - parameter session: The connect session.

     - returns: The built adapter.
     */
    override open func getAdapterFor(session: ConnectSession) -> AdapterSocket {
        let adapter = VmessAdapter(serverHost: serverHost, serverPort: serverPort, uuid: self.uuid,alterId: self.alterId,path: self.path)
        adapter.socket = RawSocketFactory.getRawSocket(.ws)
        return adapter
    }
}
