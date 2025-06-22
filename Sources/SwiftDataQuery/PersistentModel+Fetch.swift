//  PersistentModel+Fetch.swift
//  swift-query
//
//  Created by John Clayton on 2025/6/22.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import SwiftData

@MainActor
extension PersistentModel {
    static func results(container: ModelContainer) throws -> [Self] {
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

extension PersistentModel {
    static func results(isolation: isolated (any ModelActor) = #isolation) throws -> [Self] {
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
