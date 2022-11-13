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

public indirect enum Command<S> where S: Equatable {
    case noop
    case perform(any SideEffect<S>)
    case reduce(any Mutation<S>)
    case dispatch(strategy: DispatchStrategy, commands: [Command<S>])
}

public enum DispatchStrategy {
    case serial
    case concurrent
}
