//
//  SwiftTinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public typealias SideEffect<E> = (E, @escaping Dispatch) async -> Void
public typealias Reducer<S, A, E> = (inout S, A) -> SideEffect<E>? where A: Action
public typealias Dispatch = (any Action) -> Void
public protocol Action {}

private struct AnyAction: Action {
    let base: Any
    public init(_ action: any Action) {
        base = action
    }
}

@_spi(testable)
public struct MappedReducer<S, E> {
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

public class Store<S, E> {
    private let _environment: E
    private let _queue: DispatchQueue
    private let _statePub: PassthroughSubject<S, Never>

    private var _state: S
    private var _reducers: [MappedReducer<S, E>]

    public init(initialState: S,
                environment: E)
    {
        _environment = environment
        _state = initialState
        _reducers = []
        _statePub = .init()
        _queue = DispatchQueue(label: "com.swifttinyredux.queue",
                               attributes: .concurrent)
    }

    @_spi(testable)
    public var state: S {
        get { _queue.sync { _state } }
        set { _queue.sync(flags: .barrier) { _state = newValue } }
    }

    @_spi(testable)
    public var reducers: [MappedReducer<S, E>] {
        get { _queue.sync { _reducers } }
        set { _queue.sync(flags: .barrier) { _reducers = newValue } }
    }

    @_spi(testable)
    public var environment: E {
        _environment
    }

    public func add<A>(reducer: @escaping Reducer<S, A, E>)
        where A: Action
    {
        reducers.append(
            MappedReducer(state: \S.self,
                          environment: \E.self,
                          reducer: reducer)
        )
    }

    public func add<A, S1>(reducer: @escaping Reducer<S1, A, E>,
                           state stateKetPath: WritableKeyPath<S, S1>)
        where A: Action
    {
        reducers.append(
            MappedReducer(state: stateKetPath,
                          environment: \E.self,
                          reducer: reducer)
        )
    }

    public func add<A, E1>(reducer: @escaping Reducer<S, A, E1>,
                           environment environmentKeyPath: KeyPath<E, E1>)
        where A: Action
    {
        reducers.append(
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
        reducers.append(
            MappedReducer(state: stateKetPath,
                          environment: environmentKeyPath,
                          reducer: reducer)
        )
    }

    public func map<V>(_ keyPath: KeyPath<S, V>,
                       to publisher: inout Published<V>.Publisher)
        where V: Equatable
    {
        _statePub
            .prepend(state)
            .map { $0[keyPath: keyPath] }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .assign(to: &publisher)
    }

    public func map(_ publisher: inout Published<S>.Publisher)
        where S: Equatable
    {
        _statePub
            .prepend(state)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .assign(to: &publisher)
    }

    public func dispatch(action: any Action) {
        let sideEffects = _dispatch(action: action)

        Task.detached { [weak self] in
            await self?._perform(sideEffects: sideEffects)
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
                        await sideEffect(strongSelf.environment, dispatch)
                    }
                }
            }
        }
    }

    @_spi(testable)
    public func _dispatch(action: any Action) -> [SideEffect<E>] {
        var sideEffects: [SideEffect<E>] = []
        for reducer in reducers {
            var sideEffect: SideEffect<E>?
            _queue.sync(flags: .barrier) {
                var state = _state
                sideEffect = reducer(&state, action)
                _state = state
                _statePub.send(_state)
            }
            if let sideEffect = sideEffect {
                sideEffects.append(sideEffect)
            }
        }

        return sideEffects
    }
}
