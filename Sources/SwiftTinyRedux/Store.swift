//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Combine
import Foundation

public class Store<S, E> where S: Equatable {
    private let _env: E
    private var _state: S
    private let _didChangePublisher: PassthroughSubject<S, Never>
    private var _tasks: [UUID: Task<Void, Never>]
    private var _cancellables: Set<AnyCancellable> = []
    private let _queue: DispatchQueue

    public init(state: S,
                env: E) {
        _env = env
        _tasks = [:]
        _cancellables = []
        _didChangePublisher = .init()
        _state = state
        _queue = DispatchQueue(label: "com.tinyredux.store", attributes: .concurrent)
    }
}

public extension Store {
    var state: S {
        get { _queue.sync { _state } }
        set { write { _state = $0 } }
    }

    var env: E {
        _queue.sync { _env }
    }

    var didChangePublisher: AnyPublisher<S, Never> {
        _didChangePublisher.share().eraseToAnyPublisher()
    }

    private var tasks: [UUID: Task<Void, Never>] {
        get { _queue.sync { _tasks } }
        set { _queue.sync(flags: .barrier) { _tasks = newValue } }
    }

    private func write<R>(update: (inout S) -> R) -> R where S: Equatable {
        _queue.sync(flags: .barrier) {
            var state = _state
            let result = update(&state)
            if _state != state {
                _state = state
                _didChangePublisher.send(state)
            }
            return result
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
    func ingest<A>(_ publisher: any Publisher<A, Never>) where A: ActionProtocol, A.E == E, A.S == S {
        publisher.sink { [unowned self] in
            dispatch($0)
        }
        .store(in: &_cancellables)
    }

    func ingest<M>(_ publisher: any Publisher<M, Never>) where M: MutationProtocol, M.E == E, M.S == S {
        publisher.sink { [unowned self] in
            dispatch($0)
        }
        .store(in: &_cancellables)
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
