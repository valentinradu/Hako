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

struct LoginMutation: Mutation {
    func reduce(state _: inout IdentityState) -> some SideEffect {
        LoginSideEffect()
    }
}

struct LoginSideEffect: SideEffect {
    func perform(environment _: IdentityEnvironment) async -> some Mutation {
        SetUserMutation(user: .main)
    }
}

struct LogoutMutation: Mutation {
    func reduce(state: inout IdentityState) -> some SideEffect {
        state = .guest
        return SideEffectGroup {
            LogOutSideEffect()
            LogOutSideEffect()
        }
    }
}

struct LogOutSideEffect: SideEffect {
    func perform(environment: IdentityEnvironment) async -> some Mutation {
        await environment.logout()
        return .noop
    }
}

struct SetUserMutation: Mutation {
    let user: User
    func reduce(state: inout IdentityState) -> some SideEffect {
        state = .member(user)
        return .noop
    }
}

struct LikeAction: Mutation {
    func reduce(state: inout IdentityState) -> some SideEffect {
        switch state {
        case .guest:
            break
        case var .member(user):
            user.likes += 1
            state = .member(user)
        }
        return .noop
    }
}

struct ShowAlert: Mutation {
    let error: IdentityError

    func reduce(state: inout AppState) -> some SideEffect {
        state.errors.append(error)
        return .noop
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

struct AppState: Hashable {
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
            .add(context: context.partial(state: \.identity))
    }
}
