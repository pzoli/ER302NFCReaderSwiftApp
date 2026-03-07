//
//  Commands.swift
//  ER302NFCReaderSwiftApp
//
//  Created by Papp Zoltán on 2026. 03. 07..
//

import Foundation

class Commands {
    public enum LED {
        case RED, BLUE, OFF
    };

    public static func beep(msec: UInt8) -> [UInt8] {
        let data: [UInt8] = [msec]
        let result = buildCommand(cmd: ER302Driver.CMD_BEEP, data: data)
        return result
    }
    
    public static func led(_ color: LED) -> [UInt8] {
        let data: [UInt8]
        
        switch color {
        case .OFF:
            data = [0x00]
        case .RED:
            data = [0x02] // changed for my device from 0x01
        case .BLUE:
            data = [0x01] // changed for my device from 0x02
        }
        
        let result = buildCommand(cmd: ER302Driver.CMD_LED, data: data)
        return result
    }

    // MARK: - MIFARE Commands

    public static func mifareRequest() -> [UInt8] {
        let data: [UInt8] = [0x52]
        let result = buildCommand(cmd: ER302Driver.CMD_MIFARE_REQUEST, data: data)
        return result
    }
    
    public static func readBalance(sector: UInt8, block: UInt8) -> [UInt8] {
        let data: [UInt8] = [sector * 4 + block]
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_READ_BALANCE, data: data)
    }

    public static func auth2(sector: UInt8, keyString: String, keyA: Bool) -> [UInt8] {
        let key = hexToBytes(keyString)
        
        var data = [UInt8]()
        data.append(keyA ? 0x60 : 0x61)
        data.append(sector * 4)
        data.append(contentsOf: key!)
        
        let result = buildCommand(cmd: ER302Driver.CMD_MIFARE_AUTH2, data: data)
        print("auth command: \(ER302Driver.byteArrayToHexString(result))")
        return result
    }

    public static func mifareAnticolision() -> [UInt8] {
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_ANTICOLISION, data: [0x04])
    }

    public static func readFirmware() -> [UInt8] {
        return buildCommand(cmd: ER302Driver.CMD_READ_FW_VERSION, data: [])
    }

    public static func cmdHltA() -> [UInt8] {
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_HLTA, data: [])
    }

    public static func mifareULSelect() -> [UInt8] {
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_UL_SELECT, data: [])
    }

    public static func mifareULWrite(page: UInt8, data: [UInt8]) -> [UInt8] {
        var input: [UInt8] = [page]
        input.append(contentsOf: data)
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_UL_WRITE, data: input)
    }

    public static func mifareULRead(page: UInt8) -> [UInt8] {
        let input: [UInt8] = [page]
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_READ_BLOCK, data: input)
    }

    public static func mifareSelect(select: [UInt8]) -> [UInt8] {
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_SELECT, data: select)
    }

    public static func incBalance(sector: UInt8, block: UInt8, i: UInt32) -> [UInt8] {
        var data: [UInt8] = [sector * 4 + block]
        let intInc = ER302Driver.intToByteArray(i, bigEndian: false)
        data.append(contentsOf: intInc)
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_INCREMENT, data: data)
    }

    public static func decBalance(sector: UInt8, block: UInt8, i: UInt32) -> [UInt8] {
        var data: [UInt8] = [sector * 4 + block]
        let intInc = ER302Driver.intToByteArray(i, bigEndian: false)
        data.append(contentsOf: intInc)
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_DECREMENT, data: data)
    }

    public static func initBalance(sector: UInt8, block: UInt8, i: UInt32) -> [UInt8] {
        var data: [UInt8] = [sector * 4 + block]
        let intInc = ER302Driver.intToByteArray(i, bigEndian: false)
        data.append(contentsOf: intInc)
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_INITVAL, data: data)
    }

    public static func writeFourBytesToBlock(sector: UInt8, block: UInt8, dataBlock: [UInt8]) -> [UInt8] {
        var data: [UInt8] = [sector * 4 + block]
        data.append(contentsOf: dataBlock)
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_WRITE_BLOCK, data: data)
    }

    public static func writeFullBlock(sector: UInt8, block: UInt8, dataBlock: [UInt8]) -> [UInt8] {
        var data: [UInt8] = [sector * 4 + block]
        data.append(contentsOf: dataBlock)
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_WRITE_BLOCK, data: data)
    }

    public static func readBlock(sector: UInt8, block: UInt8) -> [UInt8] {
        let data: [UInt8] = [sector * 4 + block]
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_READ_BLOCK, data: data)
    }

    public static func readULPage(page: UInt8) -> [UInt8] {
        let data: [UInt8] = [page]
        return buildCommand(cmd: ER302Driver.CMD_MIFARE_READ_BLOCK, data: data)
    }
    
    // MARK: - NDEF Creation
    
    static func createNdefUrlMessage(url: String) -> [UInt8]? {
        let prefix: UInt8
        let cleanUrl: String
        
        if url.hasPrefix("https://www.") {
            cleanUrl = String(url.dropFirst(12))
            prefix = 0x02
        } else if url.hasPrefix("http://www.") {
            cleanUrl = String(url.dropFirst(11))
            prefix = 0x01
        } else if url.hasPrefix("https://") {
            cleanUrl = String(url.dropFirst(8))
            prefix = 0x04
        } else if url.hasPrefix("http://") {
            cleanUrl = String(url.dropFirst(7))
            prefix = 0x03
        } else {
            return nil // Vagy dobhatunk hibát is
        }
        
        let urlBytes = Array(cleanUrl.utf8)
        let payloadLen = urlBytes.count + 1
        
        // NDEF keretezés
        var ndef = [UInt8]()
        ndef.append(0xD1) // Record Header
        ndef.append(0x01) // Type Length
        ndef.append(UInt8(payloadLen))
        ndef.append(0x55) // Record Type: "U"
        ndef.append(prefix)
        ndef.append(contentsOf: urlBytes)
        
        // TLV boríték
        var tlv = [UInt8]()
        tlv.append(0x03) // T: NDEF Message tag
        tlv.append(UInt8(ndef.count)) // L: Length
        tlv.append(contentsOf: ndef)
        tlv.append(0xFE) // Terminator
        
        return tlv
    }
    
    static func createNdefTextMessage(text: String) -> [UInt8] {
        let langBytes = Array("en".utf8)
        let textBytes = Array(text.utf8)
        let payloadLen = 1 + langBytes.count + textBytes.count
        
        var ndef = [UInt8]()
        ndef.append(0xD1)
        ndef.append(0x01)
        ndef.append(UInt8(payloadLen))
        ndef.append(0x54) // Record Type: "T"
        
        ndef.append(UInt8(langBytes.count))
        ndef.append(contentsOf: langBytes)
        ndef.append(contentsOf: textBytes)
        
        var tlv = [UInt8]()
        tlv.append(0x03)
        tlv.append(UInt8(ndef.count))
        tlv.append(contentsOf: ndef)
        tlv.append(0xFE)
        
        return tlv
    }
    
    static func createNdefVCardMessage(name: String, phone: String, email: String) -> [UInt8] {
        let vcard = "BEGIN:VCARD\nVERSION:3.0\nFN:\(name)\nTEL:\(phone)\nEMAIL:\(email)\nEND:VCARD"
        let vcardBytes = Array(vcard.utf8)
        let typeBytes = Array("text/vcard".utf8)
        
        var ndef = [UInt8]()
        ndef.append(0xD2)
        ndef.append(UInt8(typeBytes.count))
        ndef.append(UInt8(vcardBytes.count))
        ndef.append(contentsOf: typeBytes)
        ndef.append(contentsOf: vcardBytes)
        
        var tlv = [UInt8]()
        tlv.append(0x03)
        tlv.append(UInt8(ndef.count))
        tlv.append(contentsOf: ndef)
        tlv.append(0xFE)
        
        return tlv
    }

    // MARK: - NDEF Decoding
    
    static func decodeNdefUri(data: [UInt8]) -> String? {
        guard data.count >= 7 else { return nil }
        
        let prefixCode = data[6]
        let prefix: String
        switch prefixCode {
        case 0x01: prefix = "http://www."
        case 0x02: prefix = "https://www."
        case 0x03: prefix = "http://"
        case 0x04: prefix = "https://"
        default: prefix = ""
        }
        
        let urlBytes = data[7...]
        if let urlString = String(bytes: urlBytes, encoding: .utf8) {
            return prefix + urlString
        }
        return nil
    }
    
    static func decodeNdefText(raw: [UInt8]) -> String {
        guard let typeIndex = raw.firstIndex(of: 0x54) else {
            return "Nem Text Record."
        }
        
        let payloadStartIndex = typeIndex + 1
        guard payloadStartIndex < raw.count else { return "" }
        
        let statusByte = raw[payloadStartIndex]
        let langCodeLength = Int(statusByte & 0x3F)
        
        let textStartIndex = payloadStartIndex + 1 + langCodeLength
        guard textStartIndex < raw.count else { return "" }
        
        let textBytes = raw[textStartIndex...]
        return String(bytes: textBytes, encoding: .utf8) ?? "Hiba a dekódolás során"
    }

    
    static func decodeNdefVCard(raw: Data) -> String {
        let rawData = raw.dropFirst(5)
        guard let rawString = String(data: rawData, encoding: .utf8) else {
            return "ERROR: UTF8 encoding not successfull."
        }
        
        let typeIndicator = "text/vcard"
        
        guard let range = rawString.range(of: typeIndicator) else {
            return "No VCard record found."
        }
        
        let vCardStartIndex = range.upperBound
        
        let remainingString = String(rawString[vCardStartIndex...])
        
        let vCardContent = remainingString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return vCardContent
    }
    
    // MARK: - Build

    public static func buildCommand(cmd: [UInt8], data: [UInt8]) -> [UInt8] {
        var bodyRaw = Data()
        bodyRaw.append(contentsOf: [0xFF, 0xFF]) // RESERVED
        bodyRaw.append(contentsOf: cmd)
        bodyRaw.append(contentsOf: data)
        
        let crcValue = ER302Driver.crc(Array(bodyRaw))
        bodyRaw.append(crcValue)
        
        var msgRaw = Data()
        msgRaw.append(contentsOf: [0xAA, 0xBB]) // HEADER
        
        let length = UInt16(2 + 1 + 2 + data.count)
        
        let lengthBytes = ER302Driver.shortToByteArray(length, bigEndian: false)
        msgRaw.append(contentsOf: lengthBytes)
        
        msgRaw.append(bodyRaw)
        
        return Array(msgRaw)
    }
}

