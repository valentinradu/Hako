//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Combine
import Foundation

@MainActor
public class Store<S, E>: ObservableObject where S: Equatable {
    @Published private var _state: S
    private let _env: E
    private var _tasks: [UUID: Task<Void, Never>]
    private var _cancellables: Set<AnyCancellable>

    public init(state: S,
                env: E) {
        _env = env
        _tasks = [:]
        _state = state
        _cancellables = []
    }

    deinit {
        for (_, task) in _tasks {
            task.cancel()
        }
    }
}

public extension Store {
    var state: S {
        _state
    }

    var env: E {
        _env
    }

    private func removeTask(uuid: UUID) {
        _tasks.removeValue(forKey: uuid)
    }
}

public extension Store {
    func dispatch<M>(_ mutation: M) where M: MutationProtocol, M.S == S, M.E == E {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")

        guard !mutation.isNoop else {
            return
        }

        let sideEffect = mutation.reduce(state: &_state)

        let uuid = UUID()
        let task = Task.detached { [weak self] in
            guard let self = self else { return }
            await self.perform(sideEffect)
            await self.removeTask(uuid: uuid)
        }
        _tasks[uuid] = task
    }
}

public extension Store {
    func ingest<M>(_ publisher: any Publisher<M, Never>) where M: MutationProtocol, M.E == E, M.S == S {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")

        publisher.sink { [weak self] in
            guard let self = self else { return }
            self.dispatch($0)
        }
        .store(in: &_cancellables)
    }
}

public extension Store {
    nonisolated func perform<SE>(_ sideEffect: SE) async where SE: SideEffectProtocol, SE.S == S, SE.E == E {
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
                await withTaskGroup(of: Void.self) { [weak self] group in
                    for sideEffect in groupSideEffect.sideEffects {
                        group.addTask { [weak self] in
                            guard let self = self else { return }
                            await self.perform(sideEffect)
                        }
                    }

                    await group.waitForAll()
                }
            }
        default:
            let nextMut = await sideEffect.perform(state: _state, env: _env)
            await dispatch(nextMut)
        }
    }
}
