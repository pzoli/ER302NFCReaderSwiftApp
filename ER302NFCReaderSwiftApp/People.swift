//
//  People.swift
//  ER302NFCReaderSwiftApp
//
//  Created by Papp Zoltán on 2026. 03. 10..
//

import Foundation

struct Person: Identifiable {
    let id = UUID()
    var name: String
    var email: String
    var phone: String
}
