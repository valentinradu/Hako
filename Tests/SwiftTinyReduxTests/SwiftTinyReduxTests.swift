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
        let context = Store()
        context.dispatch(SetUserMutation(user: .main))
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testPublishedState() async {
        let context = Store()
        var cancellables: Set<AnyCancellable> = []
        var wasCalledOnMainThread = false
        context.objectWillChange
            .sink {
                wasCalledOnMainThread = Thread.isMainThread
            }
            .store(in: &cancellables)

        context.dispatch(SetUserMutation(user: .main))

        XCTAssertTrue(wasCalledOnMainThread)
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testMultithreadDispatch() async {
        let context = Store(state: .init(account: .member(.main), errors: []))
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
                context.dispatch(LikeAction())
            }
        }

        wait(for: [expectation], timeout: 1)
    }
}
