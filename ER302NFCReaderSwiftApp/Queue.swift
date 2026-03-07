//
//  queue.swift
//  ER302NFCReaderSwiftApp
//
//  Created by Papp Zoltán on 2026. 03. 06..
//

struct Queue<T> {
    private var elements: [T] = []

    mutating func enqueue(_ element: T) {
        elements.append(element)
    }

    mutating func dequeue() -> T? {
        return elements.isEmpty ? nil : elements.removeFirst()
    }

    var isEmpty: Bool {
        return elements.isEmpty
    }
    
    var count: Int {
        return elements.count
    }
}

