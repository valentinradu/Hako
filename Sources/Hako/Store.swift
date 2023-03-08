//
//  File.swift
//
//
//  Created by Valentin Radu on 08/03/2023.
//

import Foundation
import SwiftUI

public class TaskPlanner<N> where N: Hashable {
    private var _storage: [N: Task<Void, Error>]

    public init() {
        _storage = [:]
    }

    public func perform(_ name: N, action: @escaping () async throws -> Void) {
        _storage[name]?.cancel()
        let task = Task { [weak self] in
            do {
                try await action()
            } catch {
                self?._storage.removeValue(forKey: name)
                throw error
            }
            self?._storage.removeValue(forKey: name)
        }
        _storage[name] = task
    }

    public func cancel(_ name: N) {
        if let task = _storage[name] {
            task.cancel()
        }
    }

    deinit {
        for (_, task) in _storage {
            task.cancel()
        }
    }
}


private enum StepResult {
    case next
    case stop
}

public struct Middleware<S> where S: Hashable {
    private typealias Perform = (AnyHashable, StoreContext<S>) async -> StepResult

    private let _perform: Perform

    public init<A, E>(environment: E, perform: @escaping (A, E, StoreContext<S>) async -> Void) {
        _perform = { action, context in
            if let action = action as? A {
                await perform(action, environment, context)
                return .stop
            }
            return .next
        }
    }

    fileprivate func perform<A>(action: A, context: StoreContext<S>) async -> StepResult where A: Hashable {
        await _perform(action, context)
    }
}

public struct Reducer<S> where S: Hashable {
    private typealias Reduce = (inout S, AnyHashable) -> StepResult
    private let _reduce: Reduce

    public init<A>(_ reduce: @escaping (inout S, A) -> Void) where A: Hashable {
        _reduce = { state, action in
            if let action = action as? A {
                reduce(&state, action)
                return .stop
            }
            return .next
        }
    }

    fileprivate func reduce<A>(state: inout S, action: A) -> StepResult where A: Hashable {
        _reduce(&state, action)
    }
}

public struct StoreContext<S> where S: Hashable {
    public typealias FetchState = () -> S
    public typealias Dispatch = (AnyHashable) -> Void
    public typealias Cancel = (AnyHashable) -> Void

    let fetchState: FetchState
    let dispatch: Dispatch
    let cancel: Cancel
}

@MainActor
private protocol UnderlyingStoreProtocol<S>: AnyObject {
    associatedtype S: Hashable

    var state: S { get set }

    func dispatch<A>(action: A) where A: Hashable
    func cancel<A>(action: A) where A: Hashable
    func add(middleware: Middleware<S>)
    func add(reducer: Reducer<S>)
}

extension UnderlyingStoreProtocol {
    func binding<A, V>(keyPath: KeyPath<S, V>,
                       action: @escaping (V) -> A) -> Binding<V> where A: Hashable {
        Binding { [self] in
            state[keyPath: keyPath]
        } set: { [self] value, _ in
            dispatch(action: action(value))
        }
    }
}

private extension UnderlyingStoreProtocol {
    var context: StoreContext<S> {
        StoreContext(fetchState: { [self] in state },
                     dispatch: { [self] in dispatch(action: $0) },
                     cancel: { [self] in cancel(action: $0) })
    }
}

@MainActor
private class RootStore<S>: UnderlyingStoreProtocol where S: Hashable {
    var state: S
    private var _reducers: [Reducer<S>]
    private var _middlewares: [Middleware<S>]
    private let _taskPlanner: TaskPlanner<AnyHashable>

    public init(initialState: S) {
        state = initialState
        _reducers = []
        _middlewares = []
        _taskPlanner = .init()
    }

    func dispatch<A>(action: A) where A: Hashable {
        _taskPlanner.perform(action) { [unowned self] in
            for middleware in _middlewares {
                let stepResult = await middleware.perform(action: action, context: context)

                switch stepResult {
                case .next:
                    continue
                case .stop:
                    return
                }
            }

            for reducer in _reducers {
                let stepResult = reducer.reduce(state: &state, action: action)

                switch stepResult {
                case .next:
                    continue
                case .stop:
                    return
                }
            }
        }
    }

    func cancel<A>(action: A) where A: Hashable {
        _taskPlanner.cancel(action)
    }

    func add(middleware: Middleware<S>) {
        _middlewares.append(middleware)
    }

    func add(reducer: Reducer<S>) {
        _reducers.append(reducer)
    }
}

@MainActor
private class LensStore<S, OS>: UnderlyingStoreProtocol where S: Hashable, OS: Hashable {
    var state: S {
        set {
            _other.state[keyPath: _stateKeyPath] = newValue
        }
        get {
            _other.state[keyPath: _stateKeyPath]
        }
    }

    private var _reducers: [Reducer<S>]
    private var _middlewares: [Middleware<S>]
    private let _taskPlanner: TaskPlanner<AnyHashable>

    private let _other: Store<OS>
    private let _stateKeyPath: WritableKeyPath<OS, S>

    public init(other: Store<OS>,
                stateKeyPath: WritableKeyPath<OS, S>) {
        _other = other
        _stateKeyPath = stateKeyPath
        _reducers = []
        _middlewares = []
        _taskPlanner = .init()
    }

    func dispatch<A>(action: A) where A: Hashable {
        _taskPlanner.perform(action) { [unowned self] in
            for middleware in _middlewares {
                let stepResult = await middleware.perform(action: action, context: context)

                switch stepResult {
                case .next:
                    continue
                case .stop:
                    return
                }
            }

            for reducer in _reducers {
                let stepResult = reducer.reduce(state: &state, action: action)

                switch stepResult {
                case .next:
                    continue
                case .stop:
                    return
                }
            }

            _other.dispatch(action: action)
        }
    }

    func cancel<A>(action: A) where A: Hashable {
        _taskPlanner.cancel(action)
    }

    func add(middleware: Middleware<S>) {
        _middlewares.append(middleware)
    }

    func add(reducer: Reducer<S>) {
        _reducers.append(reducer)
    }
}

@MainActor
public class Store<S> where S: Hashable {
    private var _underlyingStore: any UnderlyingStoreProtocol<S>

    public fileprivate(set) var state: S {
        set {
            _underlyingStore.state = newValue
        }
        get {
            _underlyingStore.state
        }
    }

    public init(initialState: S) {
        _underlyingStore = RootStore(initialState: initialState)
    }

    private init<OS>(other: Store<OS>,
                     stateKeyPath: WritableKeyPath<OS, S>) {
        _underlyingStore = LensStore(other: other, stateKeyPath: stateKeyPath)
    }

    public func add(middleware: Middleware<S>) {
        _underlyingStore.add(middleware: middleware)
    }

    public func lens<OS>(stateKeyPath: WritableKeyPath<S, OS>) -> Store<OS> {
        Store<OS>(other: self, stateKeyPath: stateKeyPath)
    }

    public func dispatch<A>(action: A) where A: Hashable {
        _underlyingStore.dispatch(action: action)
    }
}
