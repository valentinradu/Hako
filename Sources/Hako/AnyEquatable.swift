//
//  File.swift
//
//
//  Created by Valentin Radu on 08/10/2022.
//

import Foundation

struct AnyEquatable {
    let base: Any
    private let comparator: (Any) -> Bool
    init<E>(_ base: E) where E: Equatable {
        self.base = base
        comparator = { ($0 as? E) == base }
    }

    init(_ base: AnyEquatable) {
        self = base
    }
}

extension AnyEquatable: Equatable {
    static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        lhs.comparator(rhs.base) && rhs.comparator(lhs.base)
    }
}
