//
//  Hako.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public protocol SideEffectProtocol<S, E> where S: Equatable {
    associatedtype S: Equatable
    associatedtype E

    func perform(env: E) async -> any MutationProtocol<S, E>
    var isNoop: Bool { get }
}

public extension SideEffectProtocol {
    var isNoop: Bool { false }
}

public struct SideEffect<S, E>: SideEffectProtocol where S: Equatable {
    private let _perform: (E) async -> any MutationProtocol<S, E>
    public let isNoop: Bool

    public init(_ perform: @escaping (E) async -> Mutation<S, E>) {
        _perform = perform
        isNoop = false
    }

    public init<SE>(_ sideEffect: SE) where SE: SideEffectProtocol, SE.S == S, SE.E == E {
        _perform = sideEffect.perform
        isNoop = false
    }

    fileprivate init() {
        _perform = { _ in fatalError() }
        isNoop = true
    }

    public func perform(env: E) async -> any MutationProtocol<S, E> {
        await _perform(env)
    }
}

public enum SideEffectGroupStrategy {
    case serial
    case concurrent
}

public struct SideEffectGroup<S, E>: SideEffectProtocol where S: Equatable {
    let sideEffects: [SideEffect<S, E>]
    let strategy: SideEffectGroupStrategy

    public init(strategy: SideEffectGroupStrategy = .serial,
                sideEffects: [SideEffect<S, E>]) {
        self.sideEffects = sideEffects
        self.strategy = strategy
    }

    public func perform(env _: E) async -> any MutationProtocol<S, E> {
        fatalError()
    }
}

public extension SideEffectProtocol {
    static var noop: SideEffect<S, E> {
        SideEffect()
    }
}
