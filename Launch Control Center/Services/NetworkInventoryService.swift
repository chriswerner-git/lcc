//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: NetworkInventoryService.swift
//  Purpose: Read-only local network interface inventory for diagnostic display.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This service intentionally does not change UDP send/listen behavior. It only
//  reports the current local IPv4 interfaces so future network-health features
//  can be added carefully without disturbing scheduler timing or playback.
//

import Darwin
import Foundation

struct NetworkInterfaceSnapshot: Identifiable, Hashable {
    let name: String
    let ipv4Address: String
    let netmask: String?
    let broadcastAddress: String?
    let isUp: Bool
    let isRunning: Bool
    let isLoopback: Bool
    let supportsBroadcast: Bool

    var id: String {
        "\(name)-\(ipv4Address)"
    }

    var displayName: String {
        name
    }

    var availabilityText: String {
        if isLoopback {
            return "Loopback"
        }

        if isUp && isRunning {
            return "Available"
        }

        if isUp {
            return "Up"
        }

        return "Unavailable"
    }

    var availabilitySystemImage: String {
        if isLoopback {
            return "arrow.triangle.2.circlepath"
        }

        if isUp && isRunning {
            return "checkmark.circle.fill"
        }

        if isUp {
            return "exclamationmark.circle.fill"
        }

        return "xmark.circle.fill"
    }

    var supportsBroadcastText: String {
        supportsBroadcast ? "Yes" : "No"
    }
}

enum NetworkInventoryService {
    static func currentIPv4Interfaces() -> [NetworkInterfaceSnapshot] {
        var interfacesPointer: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfacesPointer) == 0,
              let firstInterface = interfacesPointer else {
            return []
        }

        defer {
            freeifaddrs(interfacesPointer)
        }

        var snapshots: [NetworkInterfaceSnapshot] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let interface = cursor {
            defer {
                cursor = interface.pointee.ifa_next
            }

            guard let addressPointer = interface.pointee.ifa_addr,
                  addressPointer.pointee.sa_family == UInt8(AF_INET),
                  let interfaceName = interface.pointee.ifa_name.map({ String(cString: $0) }),
                  let ipv4Address = ipv4String(from: addressPointer) else {
                continue
            }

            let flags = Int32(interface.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let supportsBroadcast = (flags & IFF_BROADCAST) != 0

            let snapshot = NetworkInterfaceSnapshot(
                name: interfaceName,
                ipv4Address: ipv4Address,
                netmask: ipv4String(from: interface.pointee.ifa_netmask),
                broadcastAddress: supportsBroadcast ? ipv4String(from: interface.pointee.ifa_dstaddr) : nil,
                isUp: isUp,
                isRunning: isRunning,
                isLoopback: isLoopback,
                supportsBroadcast: supportsBroadcast
            )

            snapshots.append(snapshot)
        }

        return snapshots.sorted { lhs, rhs in
            if lhs.isLoopback != rhs.isLoopback {
                return rhs.isLoopback
            }

            if lhs.isUp != rhs.isUp {
                return lhs.isUp && !rhs.isUp
            }

            if lhs.name != rhs.name {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

            return lhs.ipv4Address.localizedStandardCompare(rhs.ipv4Address) == .orderedAscending
        }
    }

    private static func ipv4String(from socketAddressPointer: UnsafePointer<sockaddr>?) -> String? {
        guard let socketAddressPointer else {
            return nil
        }

        return socketAddressPointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ipv4Pointer in
            var address = ipv4Pointer.pointee.sin_addr
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))

            guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }

            return String(cString: buffer)
        }
    }
}
