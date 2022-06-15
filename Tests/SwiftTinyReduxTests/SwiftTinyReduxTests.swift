//
//  SwiftTinyReduxTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

@testable import SwiftTinyRedux
import XCTest

final class SwiftTinyReduxTests: XCTestCase {
    private var _store: Store<AppState, AppEnvironment>!

    override func setUp() {
        let state: AppState = .init(identity: .guest, errors: [])
        let env: AppEnvironment = .init(identity: .init())
        let context = StoreContext(state: state, environment: env)
        let errorSideEffect = AnyErrorSideEffect { error, store in
            store.dispatch(action: ShowAlert(error: error))
        }
        _store = Store(context: context, errorSideEffects: [errorSideEffect])
    }

    func testSimpleDispatch() {
        let store = _store.partial(state: \.identity, environment: \.identity)
        let sideEffects = store._dispatch(action: SetUserAction(user: .main))

        XCTAssertNil(sideEffects)
        XCTAssertEqual(store.state, .member(User.main))
    }
//
//    func testThrowDispatch() async {
//        let sideEffect: SideEffect<AppEnvironment> = { _, _ in
//            throw IdentityError.unauthenticated
//        }
//        await _store._perform(sideEffects: [sideEffect])
//
//        let state = _store.state
//        XCTAssertEqual(state.errors.compactMap { $0 as? IdentityError },
//                       [IdentityError.unauthenticated])
//    }
//
//    func testMappingInitialState() async throws {
//        let vm = ProfileViewModel()
//        _ = _store._dispatch(action: IdentityAction.setUser(User.main))
//
//        _store
//            .watch(\.identity.member?.email)
//            .assign(to: &vm.$userEmail)
//
//        for try await value in vm.$userEmail.timeout(1).asyncStream() {
//            if value == User.main.email {
//                return
//            }
//        }
//
//        XCTFail()
//    }
//
//    func testMapping() async throws {
//        let vm = ProfileViewModel()
//
//        _store
//            .watch(\.identity.member?.email)
//            .assign(to: &vm.$userEmail)
//        let sideEffects = _store._dispatch(action: IdentityAction.setUser(User.main))
//
//        XCTAssertEqual(sideEffects.count, 0)
//        for try await value in vm.$userEmail.timeout(1).asyncStream() {
//            if value == User.main.email {
//                return
//            }
//        }
//
//        XCTFail()
//    }
//
//    func testPerformSideEffects() async throws {
//        let sideEffects = _store._dispatch(action: IdentityAction.logout)
//        await _store._perform(sideEffects: sideEffects)
//
//        XCTAssertEqual(sideEffects.count, 1)
//        let environment = _store.environment
//
//        for try await value in environment.identity.$logoutCalled.timeout(1).asyncStream() {
//            if value {
//                return
//            }
//        }
//
//        XCTFail()
//    }
//
//    func testMultithreadDispatch() async throws {
//        let vm = ProfileViewModel()
//        let queue = DispatchQueue(label: "com.swifttinyredux.test", attributes: .concurrent)
//
//        _store
//            .watch(\.identity.member?.likes)
//            .assign(to: &vm.$likes)
//
//        _ = _store._dispatch(action: IdentityAction.setUser(User.main))
//
//        for _ in 0 ..< 100 {
//            queue.async { [unowned self] in
//                _ = _store._dispatch(action: IdentityAction.like)
//            }
//        }
//
//        for try await value in vm.$likes.timeout(1).asyncStream() {
//            if value == 100 {
//                return
//            }
//        }
//
//        XCTFail()
//    }
}
