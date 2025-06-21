//  QueryActor.swift
//  swift-query
//
//  Created by John Clayton on 2025/6/21.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import SwiftData

@ModelActor
public actor QueryActor: Sendable {}

public extension ModelContainer {
    func actor() async throws -> QueryActor {
        .init(modelContainer: self)
    }
}
