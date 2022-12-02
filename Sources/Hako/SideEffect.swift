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
        isNoop = sideEffect.isNoop
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
    private(set) var sideEffects: [SideEffect<S, E>]
    private(set) var strategy: SideEffectGroupStrategy
    private(set) var mutation: Mutation<S, E>

    public init(strategy: SideEffectGroupStrategy = .serial,
                sideEffects: [SideEffect<S, E>]) {
        self.sideEffects = sideEffects
        self.strategy = strategy
        mutation = .noop
    }

    public init(strategy: SideEffectGroupStrategy = .serial,
                sideEffects: [SideEffect<S, E>],
                mutation: Mutation<S, E>) {
        self.sideEffects = sideEffects
        self.strategy = strategy
        self.mutation = mutation
    }

    public func perform(env: E) async -> any MutationProtocol<S, E> {
        switch strategy {
        case .serial:
            var mutations: [Mutation<S, E>] = []
            for sideEffect in sideEffects {
                if !sideEffect.isNoop {
                    await mutations.append(Mutation(sideEffect.perform(env: env)))
                }
            }
            mutations.append(mutation)
            return Mutation { state in
                var sideEffects: [SideEffect<S, E>] = []
                for mutation in mutations {
                    if !mutation.isNoop {
                        sideEffects.append(SideEffect(mutation.reduce(state: &state)))
                    }
                }

                return SideEffectGroup(strategy: strategy, sideEffects: sideEffects)
            }
        case .concurrent:
            var mutations = await withTaskGroup(of: Mutation<S, E>.self, returning: [Mutation<S, E>].self) { group in
                for sideEffect in sideEffects {
                    if !sideEffect.isNoop {
                        group.addTask {
                            Mutation(await sideEffect.perform(env: env))
                        }
                    }
                }

                var mutations: [Mutation<S, E>] = []
                while let mutation = await group.next() {
                    mutations.append(mutation)
                }

                return mutations
            }
            mutations.append(mutation)

            return Mutation { state in
                var sideEffects: [SideEffect<S, E>] = []
                for mutation in mutations {
                    if !mutation.isNoop {
                        sideEffects.append(SideEffect(mutation.reduce(state: &state)))
                    }
                }

                return SideEffectGroup(strategy: strategy, sideEffects: sideEffects)
            }
        }
    }

    public mutating func merge(_ other: SideEffectGroup<S, E>) {
        sideEffects += other.sideEffects
        if other.strategy == .concurrent {
            strategy = .concurrent
        }

        let oldMutation = mutation
        let commonStrategy = strategy
        mutation = Mutation { state in
            var sideEffects: [SideEffect<S, E>] = []

            if !oldMutation.isNoop {
                sideEffects.append(SideEffect(oldMutation.reduce(state: &state)))
            }

            if !other.mutation.isNoop {
                sideEffects.append(SideEffect(other.mutation.reduce(state: &state)))
            }

            return SideEffectGroup(strategy: commonStrategy, sideEffects: sideEffects)
        }
    }
}

public extension SideEffectProtocol {
    static var noop: SideEffect<S, E> {
        SideEffect()
    }
}
