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

extension PersistentModel {
    static func all(isolation: isolated (any ModelActor) = #isolation) throws -> [Self] {
        try query().results()
    }

    static func count(isolation: isolated (any ModelActor) = #isolation) throws -> Int {
        try query().count()
    }

    static func isEmpty(isolation: isolated (any ModelActor) = #isolation) throws -> Bool {
        try query().isEmpty()
    }

    static func findOrCreate(
        isolation: isolated (any ModelActor) = #isolation,
        body: () -> Self
    ) throws -> Self {
        try query().findOrCreate(body: body)
    }
}

@MainActor
extension PersistentModel {
    static func all(container: ModelContainer) throws -> [Self] {
        try query().results(in: container)
    }

    static func count(container: ModelContainer) throws -> Int {
        try query().count(in: container)
    }

    static func isEmpty(container: ModelContainer) throws -> Bool {
        try query().isEmpty(in: container)
    }

    static func findOrCreate(
        container: ModelContainer,
        body: () -> Self
    ) throws -> Self {
        try query().findOrCreate(in: container, body: body)
    }
}
