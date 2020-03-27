import Foundation

public protocol DNSResolverProtocol: class {
    var delegate: DNSResolverDelegate? { get set }
    func resolve(session: DNSSession)
    func restart()
    func stop()
}

public protocol DNSResolverDelegate: class {
    func didReceive(rawResponse: Data)
}

open class UDPDNSResolver: DNSResolverProtocol, NWUDPSocketDelegate {
    var socket: NWUDPSocket
    public weak var delegate: DNSResolverDelegate?
    let _address: IPAddress
    let _port: Port

    public init(address: IPAddress, port: Port) {
        socket = NWUDPSocket(host: address.presentation, port: Int(port.value))!
        _address = address
        _port = port
        socket.delegate = self
    }

    public func restart() {
        socket.disconnect()
        socket = NWUDPSocket(host: _address.presentation, port: Int(_port.value))!
        socket.delegate = self
    }

    public func resolve(session: DNSSession) {
        socket.write(data: session.requestMessage.payload)
    }

    public func stop() {
        socket.disconnect()
    }

    public func didReceive(data: Data, from: NWUDPSocket) {
        delegate?.didReceive(rawResponse: data)
    }
    
    public func didCancel(socket: NWUDPSocket) {
        
    }
}
