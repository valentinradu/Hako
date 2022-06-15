//
//  SwiftTinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public typealias SideEffect<OS, OE, E> = (E, Store<OS, OE>) async throws -> Void
public protocol Action {
    associatedtype S
    associatedtype E
    associatedtype OS
    associatedtype OE
    func reduce(state: inout S) -> SideEffect<OS, OE, E>?
}
public protocol Dispatcher {
    associatedtype S
    associatedtype E
    associatedtype OS
    associatedtype OE
    func dispatch<A>(action: A) where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE
}

public struct Store<S, E>: Dispatcher {
    public typealias OS = S
    public typealias OE = E
    private let _underlyingStore: _PartialStore<S, E, S, E>
    
    public init(origin: StoreState<S, E>) {
        _underlyingStore = _PartialStore(origin: origin, state: \.self,
                                         environment: \.self)
    }
    
    public func dispatch<A>(action: A) where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE {
        _underlyingStore.dispatch(action: action)
    }
    
    public func narrow<NS, NE>(state stateKeyPath: WritableKeyPath<S, NS>,
                               environment environmentKeyPath: KeyPath<E, NE>) -> _PartialStore<OS, OE, NS, NE> {
        _underlyingStore.narrow(state: stateKeyPath,
                                environment: environmentKeyPath)
    }
}

public struct _PartialStore<OS, OE, S, E>: Dispatcher {
    private let _origin: StoreState<OS, OE>
    private let _stateKeyPath: WritableKeyPath<OS, S>
    private let _environmentKeyPath: KeyPath<OE, E>
    
    init(origin: StoreState<OS, OE>,
                state stateKeyPath: WritableKeyPath<OS, S>,
                environment environmentKeyPath: KeyPath<OE, E>) {
        _origin = origin
        _stateKeyPath = stateKeyPath
        _environmentKeyPath = environmentKeyPath
    }

    public func dispatch<A>(action: A) where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE {
        guard let sideEffect = _dispatch(action: action) else {
            return
        }

        Task.detached {
            await self._perform(sideEffect: sideEffect)
        }
    }
    
    func narrow<NS, NE>(state stateKeyPath: WritableKeyPath<OS, NS>,
                        environment environmentKeyPath: KeyPath<OE, NE>) -> _PartialStore<OS, OE, NS, NE> {
        _PartialStore<OS, OE, NS, NE>(origin: _origin,
                              state: stateKeyPath,
                              environment: environmentKeyPath)
    }

    func _perform(sideEffect: SideEffect<OS, OE, E>) async {
        do {
            let environment = _origin.environment[keyPath: _environmentKeyPath]
            let store = Store<OS, OE>(origin: _origin)
            try await sideEffect(environment, store)
        } catch {
//            dispatch(StoreAction.error(error))
            // what should we do here?
            fatalError()
        }
    }

    func _dispatch<A>(action: A) -> SideEffect<OS, OE, E>? where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE {
        var sideEffect: SideEffect<OS, OE, E>?
        _origin.perform {
            var state = _origin.state[keyPath: _stateKeyPath]
            sideEffect = action.reduce(state: &state)
            _origin.state[keyPath: _stateKeyPath] = state
        }
        return sideEffect
    }
}

public class StoreState<S, E> {
    private let _environment: E
    private let _queue: DispatchQueue

    private var _wrappedValue: S

    public init(wrappedValue: S,
                environment: E)
    {
        _environment = environment
        _wrappedValue = wrappedValue
        _queue = DispatchQueue(label: "com.swifttinyredux.queue",
                               attributes: .concurrent)
    }

    public var state: S {
        get { _queue.sync { _wrappedValue } }
        set { _queue.sync(flags: .barrier) { _wrappedValue = newValue } }
    }

    fileprivate var environment: E {
        _queue.sync { _environment }
    }
    
    fileprivate func perform(_ update: () -> Void) {
        _queue.sync(flags: .barrier) {
            update()
        }
    }
}
