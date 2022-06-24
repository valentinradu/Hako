//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public protocol ErrorMutationProtocol {
    associatedtype S: Hashable
    associatedtype E
    func reduce(error: Error) -> SideEffect<S, E>
}

public struct ErrorMutation<S, E>: ErrorMutationProtocol where S: Hashable {
    private var _reduce: (Error) -> SideEffect<S, E>

    public init(_ reduce: @escaping (Error) -> SideEffect<S, E>) {
        _reduce = reduce
    }

    public init<EM>(wrapping: EM) where EM: ErrorMutationProtocol, EM.S == S, EM.E == E {
        _reduce = wrapping.reduce
    }

    public func reduce(error: Error) -> SideEffect<S, E> {
        _reduce(error)
    }
}

public class Store<S, E>: ObservableObject where S: Hashable {
    private let _env: E
    private let _queue: DispatchQueue
    private var _state: S
    private var _errorMutations: [ErrorMutation<S, E>]

    public init(state: S,
                env: E)
    {
        _env = env
        _state = state
        _queue = DispatchQueue(label: "com.swifttinyredux.queue",
                               attributes: .concurrent)
        _errorMutations = []
    }
}

extension Store {
    public fileprivate(set) var state: S {
        get { _queue.sync { _state } }
        set { write { $0 = newValue } }
    }

    private var env: E {
        _queue.sync { _env }
    }

    private func write<R>(update: (inout S) -> R) -> R where S: Hashable {
        if Thread.isMainThread {
            var state = _state
            let result = update(&state)
            if _state != state {
                objectWillChange.send()
                _queue.sync(flags: .barrier) {
                    _state = state
                }
            }
            return result
        }
        else {
            return DispatchQueue.main.sync {
                var state = _state
                let result = update(&state)
                if _state != state {
                    objectWillChange.send()
                    _queue.sync(flags: .barrier) {
                        _state = state
                    }
                }

                return result
            }
        }
    }
}

public extension Store {
    func dispatch<M>(_ mut: M) where M: MutationProtocol, M.S == S, M.E == E {
        guard !mut.isNoop else {
            return
        }

        let sideEffect = write { state in
            mut.reduce(state: &state)
        }

        Task.detached { [weak self] in
            do {
                try await self?.perform(sideEffect)
            }
            catch {
                self?.catchToSideEffect(error: error)
            }
        }
    }

    func dispatch<A>(_ action: A) where A: ActionProtocol, A.S == S, A.E == E {
        let sideEffect = action.perform()
        Task.detached { [weak self] in
            do {
                try await self?.perform(sideEffect)
            }
            catch {
                self?.catchToSideEffect(error: error)
            }
        }
    }
}

extension Store {
    func perform<SE>(_ sideEffect: SE) async throws where SE: SideEffectProtocol, SE.S == S, SE.E == E {
        guard !sideEffect.isNoop else {
            return
        }
        switch sideEffect {
        case let groupSideEffect as SideEffectGroup<S, E>:
            switch groupSideEffect.strategy {
            case .serial:
                for sideEffect in groupSideEffect.sideEffects {
                    try await perform(sideEffect)
                }
            case .concurrent:
                await withThrowingTaskGroup(of: Void.self) { group in
                    for sideEffect in groupSideEffect.sideEffects {
                        group.addTask { [weak self] in
                            try await self?.perform(sideEffect)
                        }
                    }
                }
            }
        default:
            let nextMut = try await sideEffect.perform(env: env)
            dispatch(nextMut)
        }
    }
}

public extension Store {
    func add<EM>(_ mut: EM) where EM: ErrorMutationProtocol, EM.S == S, EM.E == E {
        _queue.sync {
            _errorMutations.append(ErrorMutation(wrapping: mut))
        }
    }

    func catchToSideEffect(error: Error) {
        for mut in _errorMutations {
            let sideEffect = mut.reduce(error: error)
            Task.detached { [weak self] in
                do {
                    try await self?.perform(sideEffect)
                }
                catch {
                    self?.catchToSideEffect(error: error)
                }
            }
        }
    }
}
