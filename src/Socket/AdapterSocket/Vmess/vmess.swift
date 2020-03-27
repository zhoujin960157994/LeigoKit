//
//  vmess.swift
//  NEKit
//
//  Created by wfei on 2020/2/9.
//  Copyright © 2020 Zhuhao Wang. All rights reserved.
//

import Foundation

struct VmessAuth {
    var uuidData: Data
    var tsData: Data
    
    public init?(uuidString: String)  {
        guard let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        
        self.init(uuid: uuid)
    }
    
    public init(uuid: UUID) {
        self.uuidData =  withUnsafePointer(to: uuid) {
            Data(bytes: $0, count: MemoryLayout.size(ofValue: uuid))
        }
        
        self.tsData = withUnsafeBytes(of: UInt64(NSDate().timeIntervalSince1970).bigEndian, {
            Data($0)
        })
    }
    
    public mutating func update() {
        self.tsData = withUnsafeBytes(of: UInt64(NSDate().timeIntervalSince1970).bigEndian, {
            Data($0)
        })
    }
    
    public func serialize() -> Data {
        let hash = HMAC.final(value: self.tsData, algorithm: .MD5, key: self.uuidData)
        return hash
    }
}



struct VmessCommand {
    struct Options: OptionSet {
        let rawValue: UInt8
        
        static let S = Options(rawValue: 0x01)
        static let R = Options(rawValue: 0x02)
        static let M = Options(rawValue: 0x04)
    }
    
    enum SecType: UInt8 {
        case AES_128_CFB = 0x00
        case AES_128_GCM = 0x03
        case ChaCha20_Poly130 = 0x04
        case None = 0x05
    }
    
    enum Cmd: UInt8 {
        case TCP = 0x01
        case UDP = 0x02
    }
    
    enum AddressType: UInt8 {
        case IPv4 = 0x01
        case Domain = 0x02
        case IPv6 = 0x03
    }
    
    struct Address {
        let type: AddressType
        let data: Data
        
        init(withIPAddress address: IPAddress) {
            self.type = .IPv4
            self.data = address.dataInNetworkOrder
        }
        
        init(withDomain domain: String) {
            self.type = .Domain
            var data = Data()
            data.append(UInt8(domain.lengthOfBytes(using: .utf8)))
            data.append(Data(domain.utf8))
            self.data = data
        }
        
        func serialize() -> Data {
            var data = Data()
            
            data.append(self.type.rawValue)
            data.append(self.data)
            
            return data
        }
    }
    
    let ver: UInt8 = 1
    let iv: Data
    let key: Data
    let v = UInt8.random(in: 0...255)
    let opt: Options = [Options.S]
    let p = UInt8.random(in: 0...15)
    let sec = SecType.AES_128_CFB
    let reserve: UInt8 = 0
    let cmd: Cmd
    let port: UInt16
    let addr: Address
    let random: Data
    
    init(domain: String, port: UInt16, udp: Bool = false) {
        self.init(addr: Address(withDomain: domain), port: port, udp: udp)
    }
    
    init(ip: IPAddress, port: UInt16, udp: Bool = false) {
        self.init(addr: Address(withIPAddress: ip), port: port, udp: udp)
    }
    
    private init(addr: Address, port: UInt16, udp: Bool = false) {
        var ivData = Data(count: 16)
         let _ = ivData.withUnsafeMutableBytes({
               SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        })
        self.iv = ivData
        
        var keyData = Data(count: 16)
         let _ = keyData.withUnsafeMutableBytes({
               SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        })
        self.key = keyData

        let rLen = Int(self.p)
        var rData = Data(count: rLen)
         let _ = rData.withUnsafeMutableBytes({
            SecRandomCopyBytes(kSecRandomDefault, rLen, $0.baseAddress!)
        })
        self.random = rData
        
        self.addr = addr
        self.port = port
        self.cmd = udp ?.UDP : .TCP
    }
    
    func serialize(withAuth auth: inout VmessAuth) -> Data {
        var data = Data()
        
        data.append(self.ver)
        data.append(self.iv)
        data.append(self.key)
        data.append(self.v)
        data.append(self.opt.rawValue)
        data.append((self.p << 4) | self.sec.rawValue )
        data.append(self.reserve)
        data.append(self.cmd.rawValue)
        data.append(withUnsafeBytes(of: self.port.bigEndian) { Data($0) })
        data.append(self.addr.type.rawValue)
        data.append(self.addr.data)
        data.append(self.random)
        
        let hash = FVN1AHash.sum(data: data)
        data.append(withUnsafeBytes(of: hash.bigEndian) { Data($0) })
        return self.encrypt(uuid: auth.uuidData, timestamp: auth.tsData, rawCommand: data)
    }
    
    private func encrypt(uuid: Data, timestamp: Data, rawCommand: Data) -> Data {
        let sData = "c48619fe-8f02-49e0-b9e9-edf763e17e21".data(using: .utf8)!
        
        var keyData = Data()
        keyData.append(uuid)
        keyData.append(sData)
        let key = MD5Hash.final(keyData)

        var ivData = Data()
        ivData.append(timestamp)
        ivData.append(timestamp)
        ivData.append(timestamp)
        ivData.append(timestamp)
        let iv = MD5Hash.final(ivData)

        var resData = rawCommand
        let aes = CCCrypto(operation: .encrypt, mode: .cfb, algorithm: .aes, initialVector: iv, key: key)
        aes.update(&resData)
        
        return resData
    }
}

struct VmessRequest {
    var data: Data
    var tralling: Data?
    
    public static let maxLen = 2 << 14
    
    public static func Empty() -> VmessRequest{
        return VmessRequest(data: Data())
    }
    
    init(data: Data) {
        if data.count > VmessRequest.maxLen {
            self.data = data.subdata(in: 0..<VmessRequest.maxLen)
            self.tralling = data.subdata(in: VmessRequest.maxLen..<data.count)
        } else {
            self.data = data
        }
    }
    
    public func serialize(key: Data, iv: Data) -> Data {
        var sData = Data()
        let len = UInt16(self.data.count + 4)

        sData.append(withUnsafeBytes(of: len.bigEndian) { Data($0) })

        let hash = FVN1AHash.sum(data: self.data)
        sData.append(withUnsafeBytes(of: hash.bigEndian) { Data($0) })
        sData.append(self.data)
        
        return sData
    }
}

struct VmessRespHeader {
    struct Options: OptionSet {
        let rawValue: UInt8
        
        static let reuse = Options(rawValue: 0x01)
    }
    
    enum Cmd: UInt8 {
        case dport = 0x01
        case unknown
    }
    
    let minHeaderSize = 4
    
    let v: UInt8
    let opt: Options
    let cmdCode: Cmd
    let cmdLen: Int
    let cmdData: Data
    let trailing: Data
    
    init?(data: Data) {
        // Check min header size
        guard data.count >= self.minHeaderSize else {
            return nil
        }
        
        self.v = UInt8(data[0])
        self.opt = Options(rawValue: data[1])
        self.cmdCode = Cmd(rawValue: data[2]) ?? .unknown
        self.cmdLen = Int(data[3])
        
        // Check command data size
        guard data.count >= self.minHeaderSize + self.cmdLen else {
            return nil
        }
        
        var p = self.minHeaderSize
        self.cmdData = data.subdata(in: p..<p+self.cmdLen)
        
        p += self.cmdLen

        if p == data.count {
            self.trailing = Data()
        } else {
            self.trailing = data.subdata(in: p..<data.count)
        }
    }
}

struct VmessRespMessage {
    let hash: UInt32
    let body: Data
    let trailing: Data

    init?(data: Data) {
        var p = 0
        // Check body length
        guard data.count >= p + 2 else {
            return nil
        }
        
        let dataLenData = data.subdata(in: p..<p+2)
        var dataLen = Int(dataLenData.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })

        p += 2
        // Check FVNA1 hash
        guard data.count >= p + dataLen else {
            return nil
        }

        let hashData = data.subdata(in: p..<p+4)
        self.hash = UInt32(hashData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

        p += 4
        dataLen -= 4

        self.body = data.subdata(in: p..<p+dataLen)
        
        p += dataLen
        if p == data.count {
            self.trailing = Data()
        } else {
            self.trailing = data.subdata(in: p..<data.count)
        }
    }
}


struct VmessSession {
    private var auth: VmessAuth
    private var command: VmessCommand
    
    private let iv: Data
    private let key: Data

    private let decryptor: CCCrypto
    private let encryptor: CCCrypto
    
    var recvBuff = Data()
    var respHeader: VmessRespHeader?

    init(auth: inout VmessAuth, command: inout VmessCommand) {
        self.auth = auth
        self.command = command
        
        self.iv = MD5Hash.final(command.iv)
        self.key = MD5Hash.final(command.key)
        
        self.decryptor = CCCrypto(operation: .decrypt, mode: .cfb, algorithm: .aes, initialVector: self.iv, key: self.key)
        self.encryptor = CCCrypto(operation: .encrypt, mode: .cfb, algorithm: .aes, initialVector: self.command.iv, key: self.command.key)
    }
    
    public mutating func packReqHeader() -> Data {
        self.auth.update()
        
        var data = self.auth.serialize()
        data.append(self.command.serialize(withAuth: &self.auth))
        
        return data
    }
    
    public func packReq(bodyData data: Data) -> Data {
        var data: Data? = data
        var rData = Data()
        
        while data != nil {
            let req = VmessRequest(data: data!)
            rData.append(req.serialize(key: self.command.key, iv: self.command.iv))
            data = req.tralling
        }

        self.encryptor.update(&rData)
        return rData
    }
    
    public func terminateReq() -> Data {
        let req = VmessRequest.Empty()
        var rData = req.serialize(key: self.command.key, iv: self.command.iv)
        self.encryptor.update(&rData)
        return rData
    }

    public mutating func handleResp(respData data: Data) {
        var data = data
        self.decryptor.update(&data)
        self.recvBuff.append(data)
    }
    
    public mutating func unpackResp() -> Data? {
        if self.respHeader == nil {
            if let header = VmessRespHeader(data: self.recvBuff) {
                self.recvBuff = header.trailing
                self.respHeader = header
            } else {
                return nil
            }
        }
        
        if let mesg = VmessRespMessage(data: self.recvBuff) {
            self.recvBuff = mesg.trailing
            return mesg.body
        }
        
        return nil
    }
}
