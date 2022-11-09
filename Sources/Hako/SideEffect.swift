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

    func perform(state: S, env: E) async -> Mutation<S, E>
    var isNoop: Bool { get }
}

public struct SideEffect<S, E>: SideEffectProtocol where S: Equatable {
    typealias Perform = (S, E) async -> any MutationProtocol<S, E>
    private let _perform: Perform?

    public init(_ perform: @escaping (S, E) async -> Mutation<S, E>) {
        _perform = perform
    }

    public init<SE>(_ sideEffect: SE) where SE: SideEffectProtocol, SE.S == S, SE.E == E {
        if let sameTypeSideEffect = sideEffect as? SideEffect {
            self = sameTypeSideEffect
            return
        }

        _perform = sideEffect.perform
    }

    fileprivate init() {
        _perform = nil
    }

    public func perform(state: S, env: E) async -> Mutation<S, E> {
        guard let perform = _perform else {
            fatalError("Trying to perform a noop side effect")
        }
        guard !Task.isCancelled else { return .noop }
        return await Mutation(perform(state, env))
    }

    public var isNoop: Bool {
        _perform == nil
    }
}

public enum SideEffectGroupStrategy {
    case serial
    case concurrent
}

public struct SideEffectGroup<S, E>: SideEffectProtocol where S: Equatable {
    let sideEffects: [any SideEffectProtocol<S, E>]
    let strategy: SideEffectGroupStrategy

    public init(strategy: SideEffectGroupStrategy = .serial,
                sideEffects: [any SideEffectProtocol<S, E>]) {
        self.sideEffects = sideEffects
        self.strategy = strategy
    }

    public func perform(state _: S, env _: E) async -> Mutation<S, E> {
        fatalError()
    }

    public var isNoop: Bool {
        sideEffects.allSatisfy(\.isNoop)
    }
}

public extension SideEffectProtocol {
    static var noop: SideEffect<S, E> {
        SideEffect()
    }
}
