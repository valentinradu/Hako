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

typealias IdentitySideEffect = SideEffect<IdentityState, IdentityEnvironment>
typealias IdentityMutation = Mutation<IdentityState, IdentityEnvironment>

struct LoginMutation: MutationProtocol {
    func reduce(state _: inout IdentityState) -> IdentitySideEffect {
        SideEffect(wrapping: LoginSideEffect())
    }
}

struct LoginSideEffect: SideEffectProtocol {
    func perform(env _: IdentityEnvironment) async throws -> IdentityMutation {
        Mutation(wrapping: SetUserMutation(user: .main))
    }
}

struct LogoutMutation: MutationProtocol {
    func reduce(state: inout IdentityState) -> IdentitySideEffect {
        state.account = .guest
        return .noop
    }
}

struct LogOutSideEffect: SideEffectProtocol {
    func perform(env: IdentityEnvironment) async throws -> IdentityMutation {
        await env.logout()
        return .noop
    }
}

struct SetUserMutation: MutationProtocol {
    let user: User
    func reduce(state: inout IdentityState) -> IdentitySideEffect {
        state.account = .member(user)
        return .noop
    }
}

struct LikeAction: MutationProtocol {
    func reduce(state: inout IdentityState) -> IdentitySideEffect {
        switch state.account {
        case .guest:
            break
        case var .member(user):
            user.likes += 1
            state.account = .member(user)
        }
        return .noop
    }
}

struct ShowAlert: MutationProtocol {
    let error: IdentityError

    func reduce(state: inout IdentityState) -> IdentitySideEffect {
        state.errors.append(error)
        return .noop
    }
}

enum Account: Hashable {
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

struct IdentityState: Hashable {
    var account: Account
    var errors: [IdentityError]
}

extension IdentityState {
    init() {
        account = .guest
        errors = []
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

extension Publisher {
    func timeout(_ value: TimeInterval) -> Publishers.Timeout<Self, RunLoop> {
        timeout(RunLoop.SchedulerTimeType.Stride(value),
                scheduler: RunLoop.main)
    }
}

extension Store {
    convenience init(state: IdentityState = .init()) where S == IdentityState, E == IdentityEnvironment {
        self.init(state: state,
                  env: .init())
    }
}
