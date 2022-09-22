//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public class Store<S, E>: ObservableObject where S: Hashable {
    private let _env: E
    private var _state: S
    private var _tasks: [UUID: Task<Void, Never>]

    public init(state: S,
                env: E) {
        _env = env
        _state = state
        _tasks = [:]
    }

    deinit {
        _tasks.values.forEach {
            $0.cancel()
        }
    }
}

public extension Store {
    var state: S {
        get { runOnMainThread { _state } }
        set { write { $0 = newValue } }
    }

    var env: E {
        runOnMainThread { _env }
    }

    private var tasks: [UUID: Task<Void, Never>] {
        get { runOnMainThread { _tasks } }
        set { runOnMainThread { _tasks = newValue } }
    }

    private func write<R>(update: (inout S) -> R) -> R where S: Hashable {
        runOnMainThread {
            var state = _state
            let result = update(&state)
            if state != _state {
                objectWillChange.send()
                _state = state
            }
            return result
        }
    }

    private func runOnMainThread<R>(_ fn: () -> R) -> R {
        if Thread.isMainThread {
            return fn()
        } else {
            return DispatchQueue.main.sync {
                fn()
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

        let uuid = UUID()
        let task = Task.detached { [weak self] in
            await self?.perform(sideEffect)
            self?.tasks.removeValue(forKey: uuid)
        }
        tasks[uuid] = task
    }

    func dispatch<A>(_ action: A) where A: ActionProtocol, A.S == S, A.E == E {
        let sideEffect = action.perform(state: state)
        let uuid = UUID()
        let task = Task.detached { [weak self] in
            await self?.perform(sideEffect)
            self?.tasks.removeValue(forKey: uuid)
        }
        tasks[uuid] = task
    }
}

public extension Store {
    func ingest<SQ>(_ sequence: SQ) where SQ: AsyncSequence, SQ.Element: ActionProtocol, SQ.Element.E == E, SQ.Element.S == S {
        let uuid = UUID()
        let task = Task.detached { [weak self] in
            do {
                for try await value in sequence {
                    self?.dispatch(value)
                }
            } catch {
                assertionFailure()
            }
            self?.tasks.removeValue(forKey: uuid)
        }
        tasks[uuid] = task
    }

    func ingest<SQ>(_ sequence: SQ) where SQ: AsyncSequence, SQ.Element: MutationProtocol, SQ.Element.E == E, SQ.Element.S == S {
        let uuid = UUID()
        let task = Task { [weak self] in
            do {
                for try await value in sequence {
                    self?.dispatch(value)
                }
            } catch {
                assertionFailure()
            }
            self?.tasks.removeValue(forKey: uuid)
        }
        tasks[uuid] = task
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
