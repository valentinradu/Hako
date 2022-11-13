//
//  File.swift
//
//
//  Created by Valentin Radu on 13/11/2022.
//

import Foundation

public protocol Mutation<S> where S: Equatable {
    associatedtype S: Equatable
    func reduce(state: inout S) -> Command<S>
}

public protocol SideEffect<S> where S: Equatable {
    associatedtype S: Equatable
    func perform() async -> Command<S>
}

public enum Command<S> where S: Equatable {
    case noop
    case perform(any SideEffect<S>)
    case performMany(strategy: PerformManyStrategy, sideEffects: [any SideEffect<S>])
    case reduce(any Mutation<S>)
    case reduceMany([any Mutation<S>])
}

public enum PerformManyStrategy {
    case serial
    case concurrent
}
