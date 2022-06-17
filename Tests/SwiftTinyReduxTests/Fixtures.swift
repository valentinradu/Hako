//
//  Fixtures.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation
import SwiftTinyRedux

enum IdentityError: Error {
    case unauthenticated
}

typealias IdentitySideEffect = SideEffect<IdentityEnvironment>

struct LoginAction: Mutation {
    func reduce(state _: inout IdentityState) -> IdentitySideEffect {
        SideEffect { _ in
            SetUserAction(user: .main)
        }
    }
}

struct LogoutAction: Mutation {
    func reduce(state: inout IdentityState) -> IdentitySideEffect {
        state = .guest
        return SideEffect { env in
            await env.logout()
        }
    }
}

struct SetUserAction: Mutation {
    let user: User
    func reduce(state: inout IdentityState) {
        state = .member(user)
    }
}

struct LikeAction: Mutation {
    func reduce(state: inout IdentityState) {
        switch state {
        case .guest:
            break
        case var .member(user):
            user.likes += 1
            state = .member(user)
        }
    }
}

struct ShowAlert: Mutation {
    let error: IdentityError

    func reduce(state: inout AppState) {
        state.errors.append(error)
    }
}

enum IdentityState: Hashable {
    case guest
    case member(User)

    var member: User? {
        switch self {
        case .guest:
            return nil
        case let .member(user):
            return user
        }
    }
}

struct User: Hashable {
    static let main = User(name: "John",
                           email: "john@localhost.com",
                           likes: 0)
    let name: String
    let email: String
    var likes: Int
}

actor IdentityEnvironment {
    @Published var logoutCalled: Bool = false
    func logout() async {
        logoutCalled = true
    }
}

struct AppState: Equatable {
    var identity: IdentityState
    var errors: [IdentityError]
}

extension AppState {
    init() {
        self.init(identity: .guest, errors: [])
    }
}

struct AppEnvironment {
    let identity: IdentityEnvironment
}

extension AppEnvironment {
    init() {
        self.init(identity: .init())
    }
}

extension Publisher {
    func timeout(_ value: TimeInterval) -> Publishers.Timeout<Self, RunLoop> {
        timeout(RunLoop.SchedulerTimeType.Stride(value),
                scheduler: RunLoop.main)
    }
}

extension StoreContext {
    convenience init(state: AppState = .init()) where S == AppState, E == AppEnvironment {
        self.init(state: state,
                  environment: .init())
    }
}

extension StoreCoordinator {
    init(context: StoreContext<AppState, AppEnvironment>) {
        self = StoreCoordinator()
            .add(context: context)
            .add(context: context.partial(state: \.identity, environment: \.identity))
    }
}
