//
//  SwiftTinyReduxTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
@testable import SwiftTinyRedux
import XCTest

final class SwiftTinyReduxTests: XCTestCase {
    func testSimpleDispatch() {
        let context = StoreContext()
        let coordinator = StoreCoordinator(context: context)
        coordinator.dispatch(SetUserMutation(user: .main))
        XCTAssertEqual(context.state.identity, .member(User.main))
    }

    func testPublishedState() async throws {
        let context = StoreContext()
        let coordinator = StoreCoordinator(context: context)
        var cancellables: Set<AnyCancellable> = []
        var wasCalledOnMainThread = false
        context.objectWillChange
            .sink {
                wasCalledOnMainThread = Thread.isMainThread
            }
            .store(in: &cancellables)

        coordinator.dispatch(SetUserMutation(user: .main))

        XCTAssertTrue(wasCalledOnMainThread)
        XCTAssertEqual(context.state.identity, .member(User.main))
    }

    func testMultithreadDispatch() async throws {
        let context = StoreContext(state: .init(identity: .member(.main), errors: []))
        let coordinator = StoreCoordinator(context: context)
        let queue = DispatchQueue(label: "com.swifttinyredux.test", attributes: .concurrent)
        var cancellables: Set<AnyCancellable> = []
        let expectation = XCTestExpectation()
        var likeCount = 0
        context.objectWillChange
            .sink {
                likeCount += 1
                if likeCount == 100 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        for _ in 0 ..< 100 {
            queue.async {
                coordinator.dispatch(LikeAction())
            }
        }

        wait(for: [expectation], timeout: 1)
    }
}
