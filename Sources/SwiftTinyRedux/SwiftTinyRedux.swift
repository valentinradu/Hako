//
//  SwiftTinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public typealias SideEffect<OS, OE, E> = (E, Store<OS, OE>) async throws -> Void
public typealias ErrorSideEffect<OS, OE> = (Error, Store<OS, OE>) async -> Void
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

public struct AnyAction<OS, OE, S, E>: Action {
    private var _reduce: (inout S) -> SideEffect<OS, OE, E>?
    public init<A>(_ action: A) where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE {
        _reduce = action.reduce
    }

    public func reduce(state: inout S) -> SideEffect<OS, OE, E>? {
        _reduce(&state)
    }
}

public struct AnyErrorSideEffect<OS, OE> {
    private var _sideEfect: ErrorSideEffect<OS, OE>
    public init(_ sideEffect: @escaping ErrorSideEffect<OS, OE>) {
        _sideEfect = sideEffect
    }

    public func perform(error: Error, store: Store<OS, OE>) async {
        await _sideEfect(error, store)
    }
}

public struct Store<S, E>: Dispatcher {
    public typealias OS = S
    public typealias OE = E
    private let _underlyingStore: PartialStore<S, E, S, E>
    private let _errorSideEffects: [AnyErrorSideEffect<S, E>]

    public init(context: StoreContext<S, E>,
                errorSideEffects: [AnyErrorSideEffect<S, E>] = [])
    {
        _underlyingStore = PartialStore(context: context,
                                        errorSideEffects: errorSideEffects,
                                        state: \.self,
                                        environment: \.self)
        _errorSideEffects = errorSideEffects
    }

    public func dispatch<A>(action: A) where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE {
        _underlyingStore.dispatch(action: action)
    }

    public func partial<NS, NE>(state stateKeyPath: WritableKeyPath<S, NS>,
                                environment environmentKeyPath: KeyPath<E, NE>) -> PartialStore<OS, OE, NS, NE>
    {
        _underlyingStore.partial(state: stateKeyPath,
                                 environment: environmentKeyPath)
    }

    public var state: S {
        _underlyingStore.state
    }

    var environment: E {
        _underlyingStore.environment
    }
}

public extension Store {
    init(state: S, environment: E) {
        let context = StoreContext(state: state,
                                   environment: environment)
        self.init(context: context)
    }
}

public struct PartialStore<OS, OE, S, E>: Dispatcher {
    private let _context: StoreContext<OS, OE>
    private let _stateKeyPath: WritableKeyPath<OS, S>
    private let _environmentKeyPath: KeyPath<OE, E>
    private let _errorSideEffects: [AnyErrorSideEffect<OS, OE>]

    init(context: StoreContext<OS, OE>,
         errorSideEffects: [AnyErrorSideEffect<OS, OE>],
         state stateKeyPath: WritableKeyPath<OS, S>,
         environment environmentKeyPath: KeyPath<OE, E>)
    {
        _context = context
        _stateKeyPath = stateKeyPath
        _environmentKeyPath = environmentKeyPath
        _errorSideEffects = errorSideEffects
    }

    public func dispatch<A>(action: A) where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE {
        guard let sideEffect = _dispatch(action: action) else {
            return
        }

        Task.detached {
            await self._perform(sideEffect: sideEffect)
        }
    }

    public var state: S {
        _context.state[keyPath: _stateKeyPath]
    }

    var environment: E {
        _context.environment[keyPath: _environmentKeyPath]
    }

    func partial<NS, NE>(state stateKeyPath: WritableKeyPath<OS, NS>,
                         environment environmentKeyPath: KeyPath<OE, NE>) -> PartialStore<OS, OE, NS, NE>
    {
        PartialStore<OS, OE, NS, NE>(context: _context,
                                     errorSideEffects: _errorSideEffects,
                                     state: stateKeyPath,
                                     environment: environmentKeyPath)
    }

    func _perform(sideEffect: SideEffect<OS, OE, E>) async {
        let environment = _context.environment[keyPath: _environmentKeyPath]
        let store = Store<OS, OE>(context: _context, errorSideEffects: _errorSideEffects)
        do {
            try await sideEffect(environment, store)
        }
        catch {
            for errorSideEffect in _errorSideEffects {
                await errorSideEffect.perform(error: error, store: store)
            }
        }
    }

    func _dispatch<A>(action: A) -> SideEffect<OS, OE, E>? where A: Action, A.S == S, A.E == E, A.OS == OS, A.OE == OE {
        var sideEffect: SideEffect<OS, OE, E>?
        _context.perform { oldState in
            var state = oldState[keyPath: _stateKeyPath]
            sideEffect = action.reduce(state: &state)
            oldState[keyPath: _stateKeyPath] = state
        }
        return sideEffect
    }
}

public class StoreContext<S, E>: ObservableObject {
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

    public private(set) var state: S {
        get { _queue.sync { _state } }
        set {
            perform { $0 = newValue }
        }
    }

    var environment: E {
        _queue.sync { _environment }
    }

    fileprivate func perform(update: (inout S) -> Void) {
        if Thread.isMainThread {
            objectWillChange.send()
            _queue.sync(flags: .barrier) {
                update(&_state)
            }
        }
        else {
            DispatchQueue.main.sync {
                objectWillChange.send()
                _queue.sync(flags: .barrier) {
                    update(&_state)
                }
            }
        }
    }
}
