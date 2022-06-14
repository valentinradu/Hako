//
//  SwiftTinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public typealias SideEffect<E> = (E, Context) async throws -> Void
public protocol Action {
    associatedtype S
    associatedtype E
    func reduce(state: inout S) -> SideEffect<E>?
}

public struct Context {
    fileprivate typealias Dispatch = (AnyAction) -> Void
    private let _dispatch: Dispatch
    
    fileprivate init(_ dispatch: @escaping Dispatch) {
        _dispatch = dispatch
    }
    
    public func dispatch<A>(_ action: A) where A: Action {
        _dispatch(AnyAction(action))
    }
}

public struct AnyAction {
    private let _execute: (inout Any) -> Any?
    
    public init<A>(_ action: A) where A: Action {
        _execute = {
            guard var state = $0 as? A.S else {
                return nil
            }
            let sideEffect = action.reduce(state: &state)
            $0 = state
            return sideEffect
        }
    }
    
    fileprivate func reduce(state: inout Any) -> Any? {
        _execute(&state)
    }
}

public class Store<S, E> {
    private let _environment: E
    private let _queue: DispatchQueue
    private let _statePub: PassthroughSubject<S, Never>

    private var _state: S

    public init(initialState: S,
                environment: E)
    {
        _environment = environment
        _state = initialState
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
    public var environment: E {
        _environment
    }

    public func watch<V>(_ keyPath: KeyPath<S, V>) -> AnyPublisher<V, Never>
        where V: Equatable
    {
        _statePub
            .prepend(state)
            .map { $0[keyPath: keyPath] }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func watch() -> AnyPublisher<S, Never>
        where S: Equatable
    {
        _statePub
            .prepend(state)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func dispatch<A>(action: A) where A: Action, A.S == S, A.E == E {
        guard let sideEffect = _dispatch(action: action) else {
            return
        }

        Task.detached { [weak self] in
            await self?._perform(sideEffect: sideEffect)
        }
    }

    @_spi(testable)
    public func _perform(sideEffect: SideEffect<E>) async {
        do {
            let context = Context {
                
            }
            try await sideEffect(environment)
        } catch {
//            dispatch(StoreAction.error(error))
            // what should we do here?
            fatalError()
        }
    }

    @_spi(testable)
    public func _dispatch<A>(action: A) -> SideEffect<A.E>? where A: Action, A.S == S, A.E == E {
        var sideEffect: SideEffect<E>?
        _queue.sync(flags: .barrier) {
            var state = _state
            sideEffect = action.reduce(state: &state)
            _state = state
            _statePub.send(_state)
        }
        
        return sideEffect
    }
}
