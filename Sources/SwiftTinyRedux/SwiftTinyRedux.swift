//
//  SwiftTinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public protocol Mutation {
    associatedtype S: Equatable
    associatedtype SE
    func reduce(state: inout S) -> SE
}

public struct SideEffect<E> {
    private let _perform: (E) async -> AnyMutation?

    public init(_ perform: @escaping (E) async -> Void) {
        _perform = {
            await perform($0)
            return nil
        }
    }

    public init<M>(_ perform: @escaping (E) async -> M) where M: Mutation, M.SE == SideEffect<E> {
        _perform = {
            await AnyMutation(perform($0))
        }
    }

    public init<M>(_ perform: @escaping (E) async -> M) where M: Mutation, M.SE == Void {
        _perform = {
            await AnyMutation(perform($0))
        }
    }

    fileprivate func perform(environment: E) async -> AnyMutation? {
        await _perform(environment)
    }
}

private struct AnyMutation {
    private let _reduce: (Any, Any) -> Bool

    public init<M, E>(_ mutation: M) where M: Mutation, M.SE == SideEffect<E> {
        _reduce = { context, coordinator in
            guard let context = context as? AnyContext<M.S>,
                  let environment = context.environment as? E,
                  let coordinator = coordinator as? StoreCoordinator
            else {
                return false
            }

            let sideEffect = context.perform { oldState in
                mutation.reduce(state: &oldState)
            }

            Task.detached { [environment] in
                guard let nextMutation = await sideEffect.perform(environment: environment) else {
                    return
                }

                _ = coordinator.reduce(nextMutation)
            }

            return true
        }
    }

    public init<M>(_ mutation: M) where M: Mutation, M.SE == Void {
        _reduce = { context, _ in
            guard let context = context as? AnyContext<M.S> else {
                return false
            }

            context.perform { oldState in
                mutation.reduce(state: &oldState)
            }

            return true
        }
    }

    func reduce(context: Any, coordinator: Any) -> Bool {
        _reduce(context, coordinator)
    }
}

private protocol Reducer {
    func reduce(_ mutation: AnyMutation) -> Bool
}

public struct Store<S>: Reducer where S: Equatable {
    private let _context: AnyContext<S>
    private let _coordinator: StoreCoordinator

    init(context: AnyContext<S>, coordinator: StoreCoordinator) {
        _context = context
        _coordinator = coordinator
    }

    public var state: S {
        _context.state
    }

    fileprivate func reduce(_ mutation: AnyMutation) -> Bool {
        mutation.reduce(context: _context,
                        coordinator: _coordinator)
    }
}

public struct AnyReducer {
    private let _reducerBuilder: (StoreCoordinator) -> Reducer

    init<S, E>(_ context: StoreContext<S, E>) {
        _reducerBuilder = {
            Store(context: AnyContext(context), coordinator: $0)
        }
    }

    init<OS, OE, S, E>(_ context: PartialContext<OS, OE, S, E>) {
        _reducerBuilder = {
            Store(context: AnyContext(context), coordinator: $0)
        }
    }

    fileprivate func reducer(with coordinator: StoreCoordinator) -> Reducer {
        _reducerBuilder(coordinator)
    }
}

public struct AnyContext<S> where S: Equatable {
    private let _perform: ((inout S) -> Any) -> Any
    private let _environment: Any
    private let _state: S

    init<E>(_ context: StoreContext<S, E>) {
        _perform = { context.perform(on: \.self, update: $0) }
        _environment = context.environment
        _state = context.state
    }

    init<OS, OE, E>(_ context: PartialContext<OS, OE, S, E>) {
        _perform = { context.perform(update: $0) }
        _environment = context.environment
        _state = context.state
    }

    var environment: Any {
        _environment
    }

    var state: S {
        _state
    }

    func perform<R>(update: (inout S) -> R) -> R {
        _perform(update) as! R
    }
}

public struct StoreCoordinator: Reducer {
    private var _contexts: [AnyReducer]

    public init() {
        _contexts = []
    }

    init(contexts: [AnyReducer]) {
        _contexts = contexts
    }

    public func reduce<M, E>(_ mutation: M) where M: Mutation, M.SE == SideEffect<E> {
        let wasPerformed = reduce(AnyMutation(mutation))
        assert(wasPerformed)
    }

    public func reduce<M>(_ mutation: M) where M: Mutation, M.SE == Void {
        let wasPerformed = reduce(AnyMutation(mutation))
        assert(wasPerformed)
    }

    fileprivate func reduce(_ mutation: AnyMutation) -> Bool {
        for context in _contexts {
            if context.reducer(with: self).reduce(mutation) {
                return true
            }
        }
        return false
    }

    public func add<OS, OE>(context: StoreContext<OS, OE>) -> StoreCoordinator {
        StoreCoordinator(contexts: _contexts + [AnyReducer(context)])
    }

    public func add<OS, OE, S, E>(context: PartialContext<OS, OE, S, E>) -> StoreCoordinator {
        StoreCoordinator(contexts: _contexts + [AnyReducer(context)])
    }
}

public struct PartialContext<OS, OE, S, E> where S: Equatable, OS: Equatable {
    private let _stateKeyPath: WritableKeyPath<OS, S>
    private let _environmentKeyPath: KeyPath<OE, E>
    private var _context: StoreContext<OS, OE>

    public init(context: StoreContext<OS, OE>,
                stateKeyPath: WritableKeyPath<OS, S>,
                environmentKeyPath: KeyPath<OE, E>)
    {
        _stateKeyPath = stateKeyPath
        _environmentKeyPath = environmentKeyPath
        _context = context
    }

    public init(context: StoreContext<OS, OE>) where OS == S, OE == E {
        _stateKeyPath = \.self
        _environmentKeyPath = \.self
        _context = context
    }

    public private(set) var state: S {
        get { _context.state[keyPath: _stateKeyPath] }
        set { _context.state[keyPath: _stateKeyPath] = newValue }
    }

    var environment: E {
        _context.environment[keyPath: _environmentKeyPath]
    }

    fileprivate func perform<R>(update: (inout S) -> R) -> R {
        _context.perform(on: _stateKeyPath, update: update)
    }
}

public class StoreContext<S, E>: ObservableObject where S: Equatable {
    private let _environment: E
    private let _queue: DispatchQueue
    private var _state: S

    public init(state: S,
                environment: E)
    {
        _environment = environment
        _state = state
        _queue = DispatchQueue(label: "com.swifttinyredux.queue",
                               attributes: .concurrent)
    }

    public fileprivate(set) var state: S {
        get { _queue.sync { _state } }
        set { perform(on: \.self) { $0 = newValue } }
    }

    public func partial<NS, NE>(state: WritableKeyPath<S, NS>, environment: KeyPath<E, NE>) -> PartialContext<S, E, NS, NE> {
        PartialContext(context: self, stateKeyPath: state,
                       environmentKeyPath: environment)
    }

    var environment: E {
        _queue.sync { _environment }
    }

    fileprivate func perform<R, NS>(on keyPath: WritableKeyPath<S, NS>, update: (inout NS) -> R) -> R where NS: Equatable {
        if Thread.isMainThread {
            var state = _state[keyPath: keyPath]
            let result = update(&state)
            if _state[keyPath: keyPath] != state {
                objectWillChange.send()
                _queue.sync(flags: .barrier) {
                    _state[keyPath: keyPath] = state
                }
            }
            return result
        }
        else {
            return DispatchQueue.main.sync {
                var state = _state[keyPath: keyPath]
                let result = update(&state)
                if _state[keyPath: keyPath] != state {
                    objectWillChange.send()
                    _queue.sync(flags: .barrier) {
                        _state[keyPath: keyPath] = state
                    }
                }

                return result
            }
        }
    }
}
