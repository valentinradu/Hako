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
        context.dispatch(.setUser(.main))
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testPublishedState() async {
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []
        let context = Store()
        context.didChangePublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        context.dispatch(.setUser(.main))
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testMultithreadDispatch() async {
        let context = Store(state: .init(account: .member(.main), errors: []))
        let queue = DispatchQueue(label: "com.swifttinyredux.test", attributes: .concurrent)
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []
        var likeCount = 0
        context.didChangePublisher
            .sink { _ in
                likeCount += 1
                if likeCount == 100 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        for _ in 0 ..< 100 {
            queue.async {
                context.dispatch(.like)
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func testAsyncSequenceIngest() {
        var count = 0
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []
        let stream: CurrentValueSubject<Mutation, Never> = .init(.setUser(.main))
        let context = Store()
        context.didChangePublisher
            .sink { _ in
                count += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)

        context.ingest(stream)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(count, 1)
    }

    func testAsyncSideEffectGroup() {
        let context = Store()
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []

        context.didChangePublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        context.dispatch(.parallelLogin)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(context.state.account, .member(User.main))
    }
}
