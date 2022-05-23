//
//  TinyReduxTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

@testable @_spi(testable) import TinyRedux
import XCTest

final class TinyReduxTests: XCTestCase {
    private var _store: Store<AppState, AppEnvironment>!

    override func setUp() {
        let state: AppState = .init(identity: .guest)
        let env: AppEnvironment = .init(identity: .init())
        _store = Store(initialState: state,
                       environment: env)
        _store.add(reducer: identityReducer,
                   state: \.identity,
                   environment: \.identity)
    }

    func testSimpleDispatch() {
        let sideEffects = _store._dispatch(action: IdentityAction.setUser(User.main))
        let state = _store.state
        XCTAssertEqual(sideEffects.count, 0)
        XCTAssertEqual(state.identity, .member(User.main))
    }

    func testMapping() async throws {
        let vm = ProfileViewModel()

        _store.map(\.identity.member?.email,
                   to: &vm.$userEmail)
        let sideEffects = _store._dispatch(action: IdentityAction.setUser(User.main))

        XCTAssertEqual(sideEffects.count, 0)
        for try await value in vm.$userEmail.timeout(1).asyncStream() {
            if value == User.main.email {
                return
            }
        }

        XCTFail()
    }

    func testPerformSideEffects() async throws {
        let sideEffects = _store._dispatch(action: IdentityAction.logout)
        await _store._perform(sideEffects: sideEffects)

        XCTAssertEqual(sideEffects.count, 1)
        let environment = _store.environment

        for try await value in environment.identity.$logoutCalled.timeout(1).asyncStream() {
            if value {
                return
            }
        }

        XCTFail()
    }

    func testMultithreadDispatch() async throws {
        let vm = ProfileViewModel()
        let queue = DispatchQueue(label: "com.tinyredux.test", attributes: .concurrent)

        _store.map(\.identity.member?.likes,
                   to: &vm.$likes)
        _ = _store._dispatch(action: IdentityAction.setUser(User.main))

        for _ in 0 ..< 100 {
            queue.async { [unowned self] in
                _ = _store._dispatch(action: IdentityAction.like)
            }
        }

        for try await value in vm.$likes.timeout(1).asyncStream() {
            if value == 100 {
                return
            }
        }

        XCTFail()
    }
}
