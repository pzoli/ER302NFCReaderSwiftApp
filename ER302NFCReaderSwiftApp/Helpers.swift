//
//  Tools.swift
//  ER302NFCReaderSwiftApp
//
//  Created by Papp Zoltán on 2026. 03. 11..
//

import Foundation

extension String {
    subscript (r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        return String(self[start..<end])
    }
}

func hexToBytes(_ hex: String) -> [UInt8]? {
    let chars = Array(hex)
    if chars.count.isMultiple(of: 2) == false { return nil }
    return stride(from: 0, to: chars.count, by: 2).compactMap {
        UInt8(String(chars[$0..<$0+2]), radix: 16)
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhX", $0) }.joined()
    }
}
