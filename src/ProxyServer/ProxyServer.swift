import Foundation
import CocoaAsyncSocket
import Resolver

/**
 The base proxy server class.
 
 This proxy does not listen on any port.
 */
open class ProxyServer: NSObject, TunnelDelegate {
    typealias TunnelArray = [Tunnel]

    /// The port of proxy server.
    public let port: Port

    /// The address of proxy server.
    public let address: IPAddress?

    /// The type of the proxy server.
    ///
    /// This can be set to anything describing the proxy server.
    public let type: String

    /// The description of proxy server.
    open override var description: String {
        return "<\(type) address:\(String(describing: address)) port:\(port)>"
    }

    open var observer: Observer<ProxyServerEvent>?

    var tunnels: TunnelArray = []
    

    /**
     Create an instance of proxy server.
     
     - parameter address: The address of proxy server.
     - parameter port:    The port of proxy server.
     
     - warning: If you are using Network Extension, you have to set address or you may not able to connect to the proxy server.
     */
    public init(address: IPAddress?, port: Port) {
        self.address = address
        self.port = port
        type = "\(Swift.type(of: self))"

        super.init()

        self.observer = ObserverFactory.currentFactory?.getObserverForProxyServer(self)
    }

    /**
     Start the proxy server.
     
     - throws: The error occured when starting the proxy server.
     */
    open func start() throws {
        QueueFactory.executeOnQueueSynchronizedly {
            GlobalIntializer.initalize()
            self.observer?.signal(.started(self))
        }
    }

    /**
     Stop the proxy server.
     */
    open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            for tunnel in tunnels {
                tunnel.forceClose()
            }
        }

        observer?.signal(.stopped(self))
    }

    public func getEarliestTimestamp() -> Date {
        var earliestActiveTimestamp = Date()
        QueueFactory.executeOnQueueSynchronizedly {
          for tunnel in tunnels {
              if tunnel.lastActive<earliestActiveTimestamp {
                  earliestActiveTimestamp = tunnel.lastActive
              }
          }
        }
        return earliestActiveTimestamp
    }

    // deprecated
    public func memoryCheck(pThis: Tunnel) {
        var tunnel : Tunnel?

        QueueFactory.executeOnQueueSynchronizedly {
          if tunnels.count>1 {
            for tun in tunnels {
                if tunnel==nil {
                  if tun != pThis {
                    tunnel = tun
                  }
                } else if tunnel!.lastActive>tun.lastActive {
                  if tun != pThis {
                    tunnel = tun
                  }
                }
            }
            guard let index = tunnels.firstIndex(of: tunnel!) else {
                // things went strange
                return
            }

            tunnels.remove(at: index)
            tunnel?.forceClose()
            tunnel = nil
          }
        }
    }

    public func recycleTunnel() {
        var tunnel : Tunnel?
        QueueFactory.executeOnQueueSynchronizedly {
          if tunnels.count>2 {
              for tun in tunnels {
                  if tunnel==nil {
                    if Date().timeIntervalSince(tun.lastActive) > TimeInterval(0.5) {
                      tunnel = tun
                    }
                  } else if tunnel!.lastActive>tun.lastActive && Date().timeIntervalSince(tun.lastActive) > TimeInterval(0.5) {
                      tunnel = tun
                  }
              }
              if tunnel != nil {
                guard let index = tunnels.firstIndex(of: tunnel!) else {
                  // things went strange
                  return
                }

                tunnels.remove(at: index)
                tunnel?.forceClose()
                tunnel = nil
              }
          }
        }
    }

    public func recycleTunnelExcept(from: Tunnel) {
        var tunnel : Tunnel?
        QueueFactory.executeOnQueueSynchronizedly {
          if tunnels.count>2 {
              for tun in tunnels {
                  if tunnel==nil {
                    if Date().timeIntervalSince(tun.lastActive) > TimeInterval(0.5) && tun != from {
                      tunnel = tun
                    }
                  } else if tunnel!.lastActive>tun.lastActive && Date().timeIntervalSince(tun.lastActive) > TimeInterval(0.5) && tun != from {
                      tunnel = tun
                  }
              }
              if tunnel != nil {
                guard let index = tunnels.firstIndex(of: tunnel!) else {
                  // things went strange
                  return
                }

                tunnels.remove(at: index)
                tunnel?.forceClose()
                tunnel = nil
              }
          }
        }
    }

    /**
     Delegate method when the proxy server accepts a new ProxySocket from local.
     
     When implementing a concrete proxy server, e.g., HTTP proxy server, the server should listen on some port and then wrap the raw socket in a corresponding ProxySocket subclass, then call this method.
     
     - parameter socket: The accepted proxy socket.
     */
    func didAcceptNewSocket(_ socket: ProxySocket) {
        observer?.signal(.newSocketAccepted(socket, onServer: self))
        let tunnel = Tunnel(proxySocket: socket)
        tunnel.delegate = self
        QueueFactory.executeOnQueueSynchronizedly {
            tunnels.append(tunnel)
            //NSLog("NEKit Tunnel plus, tunnels.count: \(tunnels.count)")
        }
        tunnel.openTunnel()
    }

    // MARK: TunnelDelegate implementation

    /**
     Delegate method when a tunnel closed. The server will remote it internally.
     
     - parameter tunnel: The closed tunnel.
     */
    func tunnelDidClose(_ tunnel: Tunnel) {
        observer?.signal(.tunnelClosed(tunnel, onServer: self))
        guard let index = tunnels.firstIndex(of: tunnel) else {
            // things went strange
            return
        }

        QueueFactory.executeOnQueueSynchronizedly {
            tunnels.remove(at: index)
        }
    }
}
