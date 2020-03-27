import Foundation
import NetworkExtension

/// TUN interface provide a scheme to register a set of IP Stacks (implementing `IPStackProtocol`) to process IP packets from a virtual TUN interface.
open class TUNInterface {
    fileprivate weak var packetFlow: NEPacketTunnelFlow?
    fileprivate var stacks: [IPStackProtocol] = []
    
    /**
     Initialize TUN interface with a packet flow.
     
     - parameter packetFlow: The packet flow to work with.
     */
    public init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }
    
    /**
     Start processing packets, this should be called after registering all IP stacks.
     
     A stopped interface should never start again. Create a new interface instead.
     */
    open func start() {
        QueueFactory.executeOnQueueSynchronizedly {
            for stack in self.stacks {
                stack.start()
            }
            
            self.readPackets()
        }
    }
    
    /**
     Stop processing packets, this should be called before releasing the interface.
     */
    open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            self.packetFlow = nil
            
            for stack in self.stacks {
                stack.stop()
            }
            self.stacks = []
        }
    }
    
    /**
     Register a new IP stack.
     
     When a packet is read from TUN interface (the packet flow), it is passed into each IP stack according to the registration order until one of them takes it in.
     
     - parameter stack: The IP stack to append to the stack list.
     */
    open func register(stack: IPStackProtocol) {
        QueueFactory.executeOnQueueSynchronizedly {
            stack.outputFunc = self.generateOutputBlock()
            self.stacks.append(stack)
        }
    }
    
    static func memoryFootprint() -> mach_vm_size_t {
        let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
        var info = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT
        let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard
            kr == KERN_SUCCESS,
            count >= TASK_VM_INFO_REV1_COUNT
            else { return 0 }
        return info.phys_footprint
    }

    fileprivate func readPackets() {
        let mem = UInt32(TUNInterface.memoryFootprint())
        let upper_boundary : UInt32 = 13*1024*1024
        if mem>=upper_boundary {
            NSLog("NEKit controling inbound drop, mem: \(mem)")
            //TCPStack.stack.proxyServer?.recycleTunnel()
            QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.microseconds(100)) { [weak self] in
              guard let me = self else {
                NSLog("readPackets asyncAfter self has gone!")
                return
              }
              QueueFactory.executeOnQueueSynchronizedly {
                var earliestTimestamp = Date()
                  var earliestStack: IPStackProtocol? = nil
                  for stack in me.stacks {
                    let stackEarliestTimestamp = stack.getEarliestTimestamp()
                      if earliestTimestamp>stackEarliestTimestamp {
                        earliestTimestamp = stack.getEarliestTimestamp()
                          earliestStack = stack
                      }
                  }
                if earliestStack != nil {
                  earliestStack!.recycle()
                }
                QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.microseconds(500)) { [weak self] in
                  NSLog("NEKit controling recover read Packets.")
                  guard let me = self else {
                    NSLog("readPacket async recover did not success")
                    return
                  }
                  me.readPackets()
                }
              }
            }
        } else {
            //NSLog("before packetFlow?.readPackets")
            packetFlow?.readPackets { packets, versions in
                QueueFactory.getQueue().async {
                  for (i, packet) in packets.enumerated() {
                    for stack in self.stacks {
                      if stack.input(packet: packet, version: versions[i]) {
                        break
                      }
                    }
                  }
                }
                self.readPackets()
            }
        }
    }
    
    fileprivate func generateOutputBlock() -> ([Data], [NSNumber]) -> Void {
        return { [weak self] packets, versions in
            let mem = UInt32(TUNInterface.memoryFootprint())
            let upper_boundary : UInt32 = 13*1024*1024
            if mem>=upper_boundary {
                NSLog("NEKit controling outbound drop, mem: \(mem)")
            } else {
                self?.packetFlow?.writePackets(packets, withProtocols: versions)
            }
        }
    }
}
