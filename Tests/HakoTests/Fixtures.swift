//
//  Fixtures.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation
import Hako

enum IdentityError: Error {
    case unauthenticated
}

typealias IdentityCommand = Command<IdentityState>

// MARK: Update account mutation

struct UpdateAccountMutation: Mutation {
    let account: Account
    func reduce(state: inout IdentityState) -> IdentityCommand {
        state.account = account
        return .noop
    }
}

// MARK: Update errors mutation

struct UpdateErrorsMutation: Mutation {
    let errors: [IdentityError]
    func reduce(state: inout IdentityState) -> IdentityCommand {
        state.errors.append(contentsOf: errors)
        return .noop
    }
}

// MARK: Update likes mutation

struct UpdateLikesMutation: Mutation {
    let units: Int
    func reduce(state: inout IdentityState) -> IdentityCommand {
        switch state.account {
        case .guest:
            break
        case var .member(user):
            user.likes += units
            state.account = .member(user)
        }
        return .noop
    }
}

// MARK: Commands

extension IdentityCommand {
    static var login: IdentityCommand {
        .reduce(UpdateAccountMutation(account: .member(.main)))
    }

    static var logout: IdentityCommand {
        .reduce(UpdateAccountMutation(account: .guest))
    }

    static func showAlert(error: IdentityError) -> IdentityCommand {
        .reduce(UpdateErrorsMutation(errors: [error]))
    }

    static var like: IdentityCommand {
        .reduce(UpdateLikesMutation(units: 1))
    }
}

// MARK: State

enum Account: Equatable {
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

struct IdentityState: Equatable {
    var account: Account
    var errors: [IdentityError]
}

extension IdentityState {
    init() {
        account = .guest
        errors = []
    }
}

extension Store where S == IdentityState {
    convenience init() {
        self.init(state: .init())
    }
}

struct User: Equatable {
    static let main = User(name: "John",
                           email: "john@localhost.com",
                           likes: 0)
    let name: String
    let email: String
    var likes: Int
}

extension Publisher {
    func timeout(_ value: TimeInterval) -> Publishers.Timeout<Self, RunLoop> {
        timeout(RunLoop.SchedulerTimeType.Stride(value),
                scheduler: RunLoop.main)
    }
}
