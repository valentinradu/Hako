//
//  File.swift
//
//
//  Created by Valentin Radu on 18/12/2022.
//

import Foundation

public protocol Reducer<Mutation, SideEffect, State> {
    associatedtype SideEffect
    associatedtype Mutation
    associatedtype State
    mutating func reduce(_ mutation: Mutation) -> Command<Mutation, SideEffect>
    var state: State { get }
}

public struct EmptyReducer<Mutation, SideEffect, State>: Reducer {
    private let _state: State

    public init(constantState: State) {
        _state = constantState
    }

    public func reduce(_ mutation: Mutation) -> Command<Mutation, SideEffect> {
        .noop
    }

    public var state: State {
        _state
    }
}

public extension Reducer {
    static func empty(constantState: State) -> EmptyReducer<Mutation, SideEffect, State> {
        EmptyReducer(constantState: constantState)
    }
}
