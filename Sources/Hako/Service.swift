//
//  File.swift
//
//
//  Created by Valentin Radu on 13/11/2022.
//

import Foundation

public protocol Service<Mutation, SideEffect> {
    associatedtype SideEffect
    associatedtype Mutation
    func perform(_ sideEffect: SideEffect) async throws -> Command<Mutation, SideEffect>
}

public struct EmptyService<Mutation, SideEffect>: Service {
    public func perform(_ sideEffect: SideEffect) async throws -> Command<Mutation, SideEffect> {
        .noop
    }
}

public extension Service {
    static var empty: EmptyService<Mutation, SideEffect> {
        EmptyService()
    }
}
