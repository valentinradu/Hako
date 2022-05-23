//
//  TinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Foundation

public typealias SideEffect<E> = (E, Dispatch) async -> Void
public typealias Reducer<S, A, E> = (inout S, A) -> SideEffect<E>? where A: Action
public typealias Dispatch = (any Action) -> Void
public protocol Action {}

private struct AnyAction: Action {
    let base: Any
    public init(_ action: any Action) {
        base = action
    }
}

private struct MappedReducer<S, E> {
    private let _reducer: Reducer<S, AnyAction, E>

    init<S1, A, E1>(state stateKeyPath: WritableKeyPath<S, S1>,
                    environment environmentKeyPath: KeyPath<E, E1>,
                    reducer: @escaping Reducer<S1, A, E1>)
        where A: Action
    {
        _reducer = { state, action in
            if let typedAction = action.base as? A {
                let sideEffect = reducer(&state[keyPath: stateKeyPath], typedAction)

                if let sideEffect = sideEffect {
                    return { environment, dispatch in
                        await sideEffect(environment[keyPath: environmentKeyPath], dispatch)
                    }
                } else {
                    return .none
                }
            } else {
                return .none
            }
        }
    }

    func callAsFunction(_ state: inout S, _ action: any Action) -> SideEffect<E>? {
        return _reducer(&state, AnyAction(action))
    }
}

public actor Store<S, E> {
    private let _environment: E
    @Published private var _state: S
    private var _reducers: [MappedReducer<S, E>]

    public init(initialState: S,
                environment: E)
    {
        _environment = environment
        _state = initialState
        _reducers = []
    }

    @_spi(testable)
    public func _getState() -> S {
        _state
    }

    @_spi(testable)
    public func _getEnvironment() -> E {
        _environment
    }

    public func add<A>(reducer: @escaping Reducer<S, A, E>)
        where A: Action
    {
        _reducers.append(
            MappedReducer(state: \S.self,
                          environment: \E.self,
                          reducer: reducer)
        )
    }

    public func add<A, S1>(reducer: @escaping Reducer<S1, A, E>,
                           state stateKetPath: WritableKeyPath<S, S1>)
        where A: Action
    {
        _reducers.append(
            MappedReducer(state: stateKetPath,
                          environment: \E.self,
                          reducer: reducer)
        )
    }

    public func add<A, E1>(reducer: @escaping Reducer<S, A, E1>,
                           environment environmentKeyPath: KeyPath<E, E1>)
        where A: Action
    {
        _reducers.append(
            MappedReducer(state: \S.self,
                          environment: environmentKeyPath,
                          reducer: reducer)
        )
    }

    public func add<A, S1, E1>(reducer: @escaping Reducer<S1, A, E1>,
                               state stateKetPath: WritableKeyPath<S, S1>,
                               environment environmentKeyPath: KeyPath<E, E1>)
        where A: Action
    {
        _reducers.append(
            MappedReducer(state: stateKetPath,
                          environment: environmentKeyPath,
                          reducer: reducer)
        )
    }

    public func map<V>(_ keyPath: KeyPath<S, V>,
                       to publisher: inout Published<V>.Publisher)
    {
        $_state
            .receive(on: RunLoop.main)
            .map { $0[keyPath: keyPath] }
            .assign(to: &publisher)
    }

    public func map(_ publisher: inout Published<S>.Publisher) {
        $_state
            .receive(on: RunLoop.main)
            .assign(to: &publisher)
    }

    public nonisolated func dispatch(action: any Action) {
        Task {
            let sideEffects = await _dispatch(action: action)

            Task.detached { [weak self] in
                await self?._perform(sideEffects: sideEffects)
            }
        }
    }

    @_spi(testable)
    public func _perform(sideEffects: [SideEffect<E>]) async {
        await withTaskGroup(of: Void.self) { [weak self] group in
            for sideEffect in sideEffects {
                group.addTask { [weak self] in
                    if let strongSelf = self {
                        let dispatch: Dispatch = {
                            self?.dispatch(action: $0)
                        }
                        await sideEffect(strongSelf._environment, dispatch)
                    }
                }
            }
        }
    }

    @_spi(testable)
    public func _dispatch(action: any Action) -> [SideEffect<E>] {
        var sideEffects: [SideEffect<E>] = []
        for reducer in _reducers {
            if let sideEffect = reducer(&_state, action) {
                sideEffects.append(sideEffect)
            }
        }

        return sideEffects
    }
}
