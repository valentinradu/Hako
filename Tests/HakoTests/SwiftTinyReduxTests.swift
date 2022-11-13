//
//  HakoTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
@testable import Hako
import XCTest

@MainActor
final class HakoTests: XCTestCase {
    func testSimpleDispatch() {
        let context = Store()
        context.dispatch(.login)
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testPublishedState() async {
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []
        let context = Store()
        context.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        context.dispatch(.login)
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testAsyncSequenceIngest() {
        var count = 0
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []
        let stream: CurrentValueSubject<IdentityCommand, Never> = .init(.like)
        let context = Store()
        context.objectWillChange
            .sink { _ in
                count += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)

        context.ingest(stream)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(count, 1)
    }

    func testConcurrentUpdates() {
        let expectation = XCTestExpectation()
        let state = IdentityState(account: .member(.main), errors: [])
        let context = Store(state: state)

        for _ in 0 ..< 1000 {
            Task.detached {
                await context.dispatch(.like)
                guard let member = await context.state.account.member else {
                    assertionFailure()
                    return
                }
                if member.likes == 1000 {
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 3)
    }
}
