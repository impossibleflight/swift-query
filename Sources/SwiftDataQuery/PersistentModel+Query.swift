//  PersistentModel+Query.swift
//  swift-query
//
//  Created by John Clayton on 2025/4/14.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import Foundation
import SwiftData

extension PersistentModel {
    static func filtered(_ predicate: Predicate<Self>) -> FetchDescriptor<Self> {
        FetchDescriptor(predicate: predicate)
    }

    static func filtered(_ predicate: () -> Predicate<Self>) -> FetchDescriptor<Self> {
        FetchDescriptor(predicate: predicate())
    }

    static func sorted(_ sortDescriptor: SortDescriptor<Self>) -> FetchDescriptor<Self> {
        FetchDescriptor(sortBy: [sortDescriptor])
    }

    static func query(_ fetchDescriptor: FetchDescriptor<Self> = .init()) -> FetchDescriptor<Self> {
        fetchDescriptor
    }
}
