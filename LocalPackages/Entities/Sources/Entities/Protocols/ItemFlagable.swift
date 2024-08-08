//
// ItemFlagable.swift
// Proton Pass - Created on 27/04/2024.
// Copyright (c) 2024 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.
//

import Foundation

public protocol ItemFlagable: Sendable {
    var flags: Int { get set }
}

extension ItemFlagable {
//    var itemFlags: ItemFlags {
//        .init(rawValue: flags)
//    }
//    var itemFlags: ItemFlags {
//        get { .init(rawValue: flags) }
//        set { flags = newValue.rawValue }
//    }
//
    var itemFlags: ItemFlags {
        get {
            ItemFlags(rawValue: flags)
//            let currentItemFlags = ItemFlags(rawValue: flags)
//            print("woot Getting itemFlags: \(currentItemFlags)")
//            return currentItemFlags
        }
        set { flags = newValue.rawValue }
    }
}

public extension ItemFlagable {
    var monitoringDisabled: Bool {
        itemFlags.contains(.monitoringDisabled)
    }

    var isBreached: Bool {
        itemFlags.contains(.isBreached)
    }

    var isBreachedAndMonitored: Bool {
        isBreached && !monitoringDisabled
    }

    var isAliasSyncEnabled: Bool {
        !itemFlags.contains(.aliasSyncEnabled)
    }

//    mutating func updateFlag(_ flag: ItemFlags, enabled: Bool) {
//        if enabled {
//            itemFlags.insert(flag)
//        } else {
//            itemFlags.remove(flag)
//        }
//    }
    mutating func updateFlag(_ flag: ItemFlags, enabled: Bool) {
        var currentFlags = itemFlags
        print("woot before change currentFlags: \(currentFlags)")
        if enabled {
            currentFlags.insert(flag)
        } else {
            currentFlags.remove(flag)
        }
        print("woot before change currentFlags: \(currentFlags)")

        itemFlags = currentFlags // Update the underlying flags property
    }
}

public struct ItemFlags: Sendable, OptionSet {
    public var rawValue: Int
    public static let monitoringDisabled = ItemFlags(rawValue: 1 << 0)
    public static let isBreached = ItemFlags(rawValue: 1 << 1)
    public static let aliasSyncEnabled = ItemFlags(rawValue: 1 << 2)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
