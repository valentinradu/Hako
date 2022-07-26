//
//  SwiftTinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public protocol SideEffectProtocol {
    associatedtype S: Hashable
    associatedtype E

    func perform(env: E) async -> Mutation<S, E>
    var isNoop: Bool { get }
}

public extension SideEffectProtocol {
    var isNoop: Bool { false }
}

public struct SideEffect<S, E>: SideEffectProtocol where S: Hashable {
    private let _perform: (E) async -> Mutation<S, E>
    public let isNoop: Bool

    public init(_ perform: @escaping (E) async -> Mutation<S, E>) {
        _perform = perform
        isNoop = false
    }

    public init<SE>(_ sideEffect: SE) where SE: SideEffectProtocol, SE.S == S, SE.E == E {
        _perform = sideEffect.perform
        isNoop = false
    }

    public init() {
        _perform = { _ in fatalError() }
        isNoop = true
    }

    public func perform(env: E) async -> Mutation<S, E> {
        await _perform(env)
    }
}

public enum SideEffectGroupStrategy {
    case serial
    case concurrent
}

public struct SideEffectGroup<S, E>: SideEffectProtocol where S: Hashable {
    let sideEffects: [SideEffect<S, E>]
    let strategy: SideEffectGroupStrategy

    public init(strategy: SideEffectGroupStrategy = .serial,
                sideEffects: [SideEffect<S, E>]) {
        self.sideEffects = sideEffects
        self.strategy = strategy
    }

    public func perform(env _: E) async -> Mutation<S, E> {
        .noop
    }
}

public extension SideEffect {
    static var noop: SideEffect<S, E> { SideEffect() }
}
