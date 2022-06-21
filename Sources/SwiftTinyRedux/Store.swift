//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public protocol ErrorReducer {
    associatedtype SE: SideEffect
    func reduce(error: Error) -> SE
}

public struct AnyErrorReducer: ErrorReducer {
    private let _reduce: (Error) -> AnySideEffect

    public init<ER>(_ reducer: ER) where ER: ErrorReducer {
        _reduce = {
            AnySideEffect(reducer.reduce(error: $0))
        }
    }

    public func reduce(error: Error) -> some SideEffect {
        _reduce(error)
    }
}

public struct StoreCoordinator: Dispatcher {
    private var _reducers: [ReducerFactory]
    private var _errorReducers: [AnyErrorReducer]

    public init() {
        _reducers = []
        _errorReducers = []
    }

    fileprivate init(reducers: [ReducerFactory],
                     errorReducers: [AnyErrorReducer])
    {
        _reducers = reducers
        _errorReducers = errorReducers
    }

    public func add<OS, OE>(context: StoreContext<OS, OE>) -> StoreCoordinator where OS: Hashable {
        let newReducers = _reducers + [ReducerFactory(context)]
        return StoreCoordinator(reducers: newReducers,
                                errorReducers: _errorReducers)
    }

    public func add<OS, OE, S>(context: PartialContext<OS, OE, S>) -> StoreCoordinator where S: Hashable {
        let newReducers = _reducers + [ReducerFactory(context)]
        return StoreCoordinator(reducers: newReducers,
                                errorReducers: _errorReducers)
    }

    public func add<ER>(errorReducer: ER) -> StoreCoordinator where ER: ErrorReducer {
        let newFactories = _errorReducers + [AnyErrorReducer(errorReducer)]
        return StoreCoordinator(reducers: _reducers,
                                errorReducers: newFactories)
    }

    public func catchToSideEffect(error: Error) {
        for errorReducer in _errorReducers {
            let sideEffect = errorReducer.reduce(error: error)
            let action = ForwardAction(sideEffect: sideEffect)
            dispatch(AnyAction(action))
        }
    }
    
    public func dispatch<A>(_ action: A) where A: Action {
        dispatch(AnyAction(action))
    }
    
    public func dispatch<M>(_ mutation: M) where M: Mutation {
        dispatch(AnyMutation(mutation))
    }

    func dispatch(_ item: AnyMutation) {
        for context in _reducers {
            context.reducer(with: self).dispatch(item)
        }
    }

    func dispatch(_ item: AnyAction) {
        for context in _reducers {
            context.reducer(with: self).dispatch(item)
        }
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

    public func partial<NS>(state: WritableKeyPath<S, NS>) -> PartialContext<S, E, NS> {
        PartialContext(context: self, stateKeyPath: state)
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

public struct PartialContext<OS, OE, S> where S: Equatable, OS: Equatable {
    private let _stateKeyPath: WritableKeyPath<OS, S>
    private var _context: StoreContext<OS, OE>

    public init(context: StoreContext<OS, OE>,
                stateKeyPath: WritableKeyPath<OS, S>)
    {
        _stateKeyPath = stateKeyPath
        _context = context
    }

    public init(context: StoreContext<OS, OE>) where OS == S {
        _stateKeyPath = \.self
        _context = context
    }

    public private(set) var state: S {
        get { _context.state[keyPath: _stateKeyPath] }
        set { _context.state[keyPath: _stateKeyPath] = newValue }
    }

    var environment: OE {
        _context.environment
    }

    fileprivate func perform<R>(update: (inout S) -> R) -> R {
        _context.perform(on: _stateKeyPath, update: update)
    }
}

private struct ForwardAction<SE>: Action where SE: SideEffect {
    let sideEffect: SE
    func perform() -> some SideEffect {
        sideEffect
    }
}

struct AnyContext<S> where S: Equatable {
    private let _perform: ((inout S) -> Any) -> Any
    private let _environment: Any
    private let _state: S

    init<E>(_ context: StoreContext<S, E>) {
        _perform = { context.perform(on: \.self, update: $0) }
        _environment = context.environment
        _state = context.state
    }

    init<OS, OE>(_ context: PartialContext<OS, OE, S>) {
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

private protocol Dispatcher {
    func dispatch(_ item: AnyMutation) -> Void
    func dispatch(_ item: AnyAction) -> Void
}

private struct Store<S>: Dispatcher where S: Hashable {
    private let _context: AnyContext<S>
    private let _coordinator: StoreCoordinator

    init(context: AnyContext<S>, coordinator: StoreCoordinator) {
        _context = context
        _coordinator = coordinator
    }

    func perform(_ sideEffect: AnySideEffect) async throws {
        if let tupleSideEffect = sideEffect.base as? _TupleSideEffect {
            switch tupleSideEffect.strategy {
            case .serial:
                for sideEffect in tupleSideEffect.children {
                    try await perform(sideEffect)
                }
            case .concurrent:
                await withThrowingTaskGroup(of: Void.self) { group in
                    for sideEffect in tupleSideEffect.children {
                        group.addTask {
                            try await perform(sideEffect)
                        }
                    }
                }
            }
        }
        else {
            let nextMutation = try await sideEffect.perform(environment: _context.environment)
            _coordinator.dispatch(AnyMutation(nextMutation))
        }
    }

    func dispatch(_ mutation: AnyMutation) {
        if type(of: mutation.base) == EmptyMutation.self {
            return
        }

        let sideEffect = _context.perform { (state: inout S) -> AnySideEffect in
            var oldState = AnyHashable(state)
            let sideEffect = mutation.reduce(state: &oldState)
            state = oldState.base as! S
            return AnySideEffect(sideEffect)
        }

        if type(of: sideEffect.base) == EmptySideEffect.self {
            return
        }

        Task.detached {
            do {
                try await perform(sideEffect)
            }
            catch {
                _coordinator.catchToSideEffect(error: error)
            }
        }
    }

    func dispatch(_ action: AnyAction) {
        let sideEffect = AnySideEffect(action.perform())

        if type(of: sideEffect.base) == EmptySideEffect.self {
            return
        }

        Task.detached {
            do {
                try await perform(sideEffect)
            }
            catch {
                _coordinator.catchToSideEffect(error: error)
            }
        }
    }
}

private struct ReducerFactory {
    private let _make: (StoreCoordinator) -> Dispatcher

    init<S, E>(_ context: StoreContext<S, E>) where S: Hashable {
        _make = {
            Store(context: AnyContext(context), coordinator: $0)
        }
    }

    init<OS, OE, S>(_ context: PartialContext<OS, OE, S>) where S: Hashable {
        _make = {
            Store(context: AnyContext(context), coordinator: $0)
        }
    }

    fileprivate func reducer(with coordinator: StoreCoordinator) -> Dispatcher {
        _make(coordinator)
    }
}
