//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public class Store<S, E>: ObservableObject where S: Hashable {
    private let _env: E
    private let _queue: DispatchQueue
    private var _state: S

    public init(state: S,
                env: E) {
        _env = env
        _state = state
        _queue = DispatchQueue(label: "com.swifttinyredux.queue",
                               attributes: .concurrent)
    }
}

public extension Store {
    var state: S {
        get { _queue.sync { _state } }
        set { write { $0 = newValue } }
    }

    var env: E {
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
        } else {
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
            await self?.perform(sideEffect)
        }
    }

    func dispatch<A>(_ action: A) where A: ActionProtocol, A.S == S, A.E == E {
        let sideEffect = action.perform()
        Task.detached { [weak self] in
            await self?.perform(sideEffect)
        }
    }
}

extension Store {
    func perform<SE>(_ sideEffect: SE) async where SE: SideEffectProtocol, SE.S == S, SE.E == E {
        guard !sideEffect.isNoop else {
            return
        }
        switch sideEffect {
        case let groupSideEffect as SideEffectGroup<S, E>:
            switch groupSideEffect.strategy {
            case .serial:
                for sideEffect in groupSideEffect.sideEffects {
                    await perform(sideEffect)
                }
            case .concurrent:
                await withTaskGroup(of: Void.self) { group in
                    for sideEffect in groupSideEffect.sideEffects {
                        group.addTask { [weak self] in
                            await self?.perform(sideEffect)
                        }
                    }
                }
            }
        default:
            let nextMut = await sideEffect.perform(env: env)
            dispatch(nextMut)
        }
    }
}
