import Foundation

public typealias SideEffect<E> = (E, Dispatch) async -> Void
public typealias Reducer<S, A, E> = (inout S, A) -> SideEffect<E>?
public typealias Dispatch = (Any) -> Void
private typealias AnySideEffect = (Any, Dispatch) async -> Void
private typealias AnyReducer = (inout Any, Any) -> AnySideEffect?

private struct MappedReducer<S, E> {
    let stateKeyPath: PartialKeyPath<S>
    let environmentKeyPath: PartialKeyPath<E>

    private let _reducer: AnyReducer

    init<S1, A, E1>(state stateKeyPath: KeyPath<S, S1>,
                    environment environmentKeyPath: KeyPath<E, E1>,
                    reducer: @escaping Reducer<S1, A, E1>)
    {
        self.stateKeyPath = stateKeyPath
        self.environmentKeyPath = environmentKeyPath
        _reducer = { state, action in
            if var typedState = state as? S1,
               let typedAction = action as? A
            {
                let sideEffect = reducer(&typedState, typedAction)
                state = typedState

                if let sideEffect = sideEffect {
                    return { environment, dispatch in
                        if let typedEnvironment = environment as? E1 {
                            await sideEffect(typedEnvironment, dispatch)
                        }
                    }
                } else {
                    return .none
                }
            } else {
                return .none
            }
        }
    }

    func callAsFunction(_ state: inout Any, _ action: Any) -> AnySideEffect? {
        return _reducer(&state, action)
    }
}

public class Store<S, E> {
    private let _environment: E
    private let _queue: DispatchQueue
    @Published private var _state: S
    private var _reducers: [MappedReducer<S, E>]

    public init(initialState: S,
                environment: E)
    {
        _queue = .init(label: "com.tinyredux.queue",
                       attributes: .concurrent,
                       autoreleaseFrequency: .workItem)
        _environment = environment
        _state = initialState
        _reducers = []
    }

    private var state: S {
        get {
            _queue.sync { _state }
        }
        set {
            _queue.sync(flags: .barrier) { _state = newValue }
        }
    }

    private var reducers: [MappedReducer<S, E>] {
        get {
            _queue.sync { _reducers }
        }
        set {
            _queue.sync(flags: .barrier) { _reducers = newValue }
        }
    }

    private var environment: E {
        return _environment
    }

    public func add<A>(reducer: @escaping Reducer<S, A, E>) {
        reducers.append(
            MappedReducer(state: \S.self,
                          environment: \E.self,
                          reducer: reducer)
        )
    }

    public func add<A, S1>(reducer: @escaping Reducer<S1, A, E>,
                           state stateKetPath: KeyPath<S, S1>)
    {
        reducers.append(
            MappedReducer(state: stateKetPath,
                          environment: \E.self,
                          reducer: reducer)
        )
    }

    public func add<A, E1>(reducer: @escaping Reducer<S, A, E1>,
                           environment environmentKeyPath: KeyPath<E, E1>)
    {
        reducers.append(
            MappedReducer(state: \S.self,
                          environment: environmentKeyPath,
                          reducer: reducer)
        )
    }

    public func add<A, S1, E1>(reducer: @escaping Reducer<S1, A, E1>,
                               state stateKetPath: KeyPath<S, S1>,
                               environment environmentKeyPath: KeyPath<E, E1>)
    {
        reducers.append(
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

    public func dispatch<A>(action: A) {
        for reducer in reducers {
            if let stateKeyPath = reducer.stateKeyPath as? WritableKeyPath<S, Any>,
               let environmentKeyPath = reducer.environmentKeyPath as? KeyPath<E, Any>
            {
                if let sideEffect = reducer(&state[keyPath: stateKeyPath], action) {
                    let environment = self.environment
                    let send: Dispatch = self.dispatch
                    Task.detached {
                        await sideEffect(environment[keyPath: environmentKeyPath], send)
                    }
                }
            }
        }
    }
}
