import Foundation
import NetworkExtension
import CocoaLumberjackSwift
import Starscream

/// The TCP socket build upon `WebSocket`.
///
/// - warning: This class is not thread-safe.
public class WSSocket: NSObject, RawTCPSocketProtocol, WebSocketDelegate {
    private var socket: WebSocket?
    
    private var writePending = false
    private var closeAfterWriting = false
    private var cancelled = false
    
    private var scanner: StreamScanner!
    private var scanning: Bool = false
    private var readDataPrefix: Data?
    
    // MARK: RawTCPSocketProtocol implementation
    
    /// The `RawTCPSocketDelegate` instance.
    weak open var delegate: RawTCPSocketDelegate?
    
    /// If the socket is connected.
    public var isConnected: Bool {
        return !self.cancelled
    }
    
    /// The source address.
    ///
    /// - note: Always returns `nil`.
    public var sourceIPAddress: IPAddress? {
        return nil
    }
    
    /// The source port.
    ///
    /// - note: Always returns `nil`.
    public var sourcePort: Port? {
        return nil
    }
    
    /// The destination address.
    ///
    /// - note: Always returns `nil`.
    public var destinationIPAddress: IPAddress? {
        return nil
    }
    
    /// The destination port.
    ///
    /// - note: Always returns `nil`.
    public var destinationPort: Port? {
        return nil
    }
    
    /**
     Connect to remote host.
     
     - parameter host:        Remote host.
     - parameter port:        Remote port.
     - parameter enableTLS:   Should TLS be enabled.
     - parameter tlsSettings: The settings of TLS.
     
     - throws: Never throws.
     */
    public func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [AnyHashable: Any]? = nil) throws {
        var path = "/"
        if let tlsSettings = tlsSettings as? [String: AnyObject] {
            if let tlsPath = tlsSettings["path"] as? String {
                path = tlsPath
            }
        }
        if port == 443 {
            self.socket = WebSocket(request: URLRequest(url: URL(string: "wss://\(host)\(path)")!), certPinner: nil)
        }else {
            self.socket = WebSocket(request: URLRequest(url: URL(string: "wss://\(host):\(port)\(path)")!), certPinner: nil)
        }
        self.socket?.delegate = self
        self.socket?.connect()
    }
    
    /**
     Disconnect the socket.
     
     The socket will disconnect elegantly after any queued writing data are successfully sent.
     */
    public func disconnect() {
        cancelled = true
        socket?.disconnect()
    }
    
    /**
     Disconnect the socket immediately.
     */
    public func forceDisconnect() {
        cancelled = true
        socket?.forceDisconnect()
    }
    
    /**
     Send data to remote.
     
     - parameter data: Data to send.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    public func write(data: Data) {
        guard !cancelled else {
            return
        }
        
        QueueFactory.getQueue().async {
            self.delegate?.didWrite(data: data, by: self)
        }
        
        if data.count > 0 {
            self.socket?.write(data: data, completion: nil)
        }
    }
    
    public func readData() {
    }
    public func readDataTo(length: Int) {
    }
    public func readDataTo(data: Data) {
    }
    public func readDataTo(data: Data, maxLength: Int) {
        return
    }
    
    private func queueCall(_ block: @escaping () -> Void) {
        QueueFactory.getQueue().async(execute: block)
    }
    
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected:
            queueCall {
                self.delegate?.didConnectWith(socket: self)
            }
        case .disconnected:
            cancelled = true
            queueCall {
                let delegate = self.delegate
                self.delegate = nil
                delegate?.didDisconnectWith(socket: self)
            }
            
        case .cancelled:
            cancelled = true
            
        case .binary(let data):
            queueCall {
                self.delegate?.didRead(data: data, from: self)
            }
            
        case .error(let error):
            DDLogError("WSSocket got an error: \(String(describing: error))")
            self.forceDisconnect()
            
        default:
            break
        }
    }
}
