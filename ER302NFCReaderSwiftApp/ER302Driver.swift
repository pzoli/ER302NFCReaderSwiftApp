//
//  ER302Driver.swift
//  Homework4SerialPort
//
//  Created by Papp Zoltán on 2026. 03. 03..
//

import Foundation

/// Driver for Ehuoyan's YHY523U module
/// Translated from Java to Swift
class ER302Driver {
    
    // MARK: - Helper Classes
    
    class CommandStruct {
        var id: Int
        var cmd: [UInt8]
        var description: String
        var result: ReceivedStruct?
        
        init(id: Int, description: String, cmd: [UInt8]) {
            self.id = id
            self.description = description
            self.cmd = cmd
        }
    }
    
    struct ReceivedStruct: Codable {
        var length: Int = 0
        var cmd: [UInt8] = []
        var data: [UInt8] = []
        var crc: UInt8 = 0
        var isValid: Bool = false
        var error: UInt8 = 0
        var log: [String] = []
        
        // JSON-hoz hex string konverzió (Jackson helyett Codable-lel)
        enum CodingKeys: String, CodingKey {
            case length, cmd, data, crc, isValid = "valid", error, log
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(length, forKey: .length)
            try container.encode(cmd.map { String(format: "%02X", $0) }.joined(), forKey: .cmd)
            try container.encode(data.map { String(format: "%02X", $0) }.joined(), forKey: .data)
            try container.encode(crc, forKey: .crc)
            try container.encode(isValid, forKey: .isValid)
            try container.encode(error, forKey: .error)
            try container.encode(log, forKey: .log)
        }

        func asJSONString() -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            guard let data = try? encoder.encode(self),
                  let string = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return string
        }

    }
    
    // MARK: - Mifare types
    public static let TYPE_MIFARE_UL: [UInt8] = [0x44, 0x00]
    public static let TYPE_MIFARE_1K: [UInt8] = [0x04, 0x00]
    public static let TYPE_MIFARE_4K: [UInt8] = [0x02, 0x00]
    public static let TYPE_MIFARE_DESFIRE: [UInt8] = [0x44, 0x03]
    public static let TYPE_MIFARE_PRO: [UInt8] = [0x08, 0x00]

    // MARK: - Command header
    public static let HEADER: [UInt8] = [0xAA, 0xBB]
    // \x00\x00 according to API reference but only works with YHY632
    // \xFF\xFF works for both.
    public static let RESERVED: [UInt8] = [0xFF, 0xFF]

    // MARK: - Serial commands
    public static let CMD_SET_BAUDRATE: [UInt8] = [0x01, 0x01]
    public static let CMD_SET_NODE_NUMBER: [UInt8] = [0x02, 0x01]
    public static let CMD_READ_NODE_NUMBER: [UInt8] = [0x03, 0x01]
    public static let CMD_READ_FW_VERSION: [UInt8] = [0x04, 0x01]
    public static let CMD_BEEP: [UInt8] = [0x06, 0x01]
    public static let CMD_LED: [UInt8] = [0x07, 0x01]
    public static let CMD_RFU: [UInt8] = [0x08, 0x01] // Unused according to API reference
    public static let CMD_WORKING_STATUS: [UInt8] = [0x08, 0x01] // Unused according to API reference
    public static let CMD_ANTENNA_POWER: [UInt8] = [0x0C, 0x01]

    /*
     Request a type of card
     data = 0x52: request all Type A card In field,
     data = 0x26: request idle card
     */
    public static let CMD_MIFARE_REQUEST: [UInt8] = [0x01, 0x02]
    public static let CMD_MIFARE_ANTICOLISION: [UInt8] = [0x02, 0x02] // 0x04 -> <NUL> (00)     [4cd90080]-cardnumber
    public static let CMD_MIFARE_SELECT: [UInt8] = [0x03, 0x02] // [4cd90080] -> 0008
    public static let CMD_MIFARE_HLTA: [UInt8] = [0x04, 0x02]
    public static let CMD_MIFARE_AUTH2: [UInt8] = [0x07, 0x02] // 60[sector*4][key]
    public static let CMD_MIFARE_READ_BLOCK: [UInt8] = [0x08, 0x02] //[block_number]
    public static let CMD_MIFARE_WRITE_BLOCK: [UInt8] = [0x09, 0x02]
    public static let CMD_MIFARE_INITVAL: [UInt8] = [0x0A, 0x02]
    public static let CMD_MIFARE_READ_BALANCE: [UInt8] = [0x0B, 0x02]
    public static let CMD_MIFARE_DECREMENT: [UInt8] = [0x0C, 0x02]
    public static let CMD_MIFARE_INCREMENT: [UInt8] = [0x0D, 0x02]
    public static let CMD_MIFARE_UL_SELECT: [UInt8] = [0x12, 0x02]
    public static let CMD_MIFARE_UL_WRITE: [UInt8] = [0x13, 0x02]

    // MARK: - Default keys
    public static let DEFAULT_KEYS: [String] = [
        "000000000000",
        "a0a1a2a3a4a5",
        "b0b1b2b3b4b5",
        "4d3a99c351dd",
        "1a982c7e459a",
        "FFFFFFFFFFFF",
        "d3f7d3f7d3f7",
        "aabbccddeeff"
    ]

    // MARK: - Error codes
    public static let ERR_BAUD_RATE: Int = 1
    public static let ERR_PORT_OR_DISCONNECT: Int = 2
    public static let ERR_GENERAL: Int = 10
    public static let ERR_UNDEFINED: Int = 11
    public static let ERR_COMMAND_PARAMETER: Int = 12
    public static let ERR_NO_CARD: Int = 13
    public static let ERR_REQUEST_FAILURE: Int = 20
    public static let ERR_RESET_FAILURE: Int = 21
    public static let ERR_AUTHENTICATE_FAILURE: Int = 22
    public static let ERR_READ_BLOCK_FAILURE: Int = 23
    public static let ERR_WRITE_BLOCK_FAILURE: Int = 24
    public static let ERR_READ_ADDRESS_FAILURE: Int = 25
    public static let ERR_WRITE_ADDRESS_FAILURE: Int = 26
    
    // MARK: - Byte Utilities
    
    static func crc(_ input: [UInt8]) -> UInt8 {
        return input.reduce(0) { $0 ^ $1 }
    }
    
    static func byteArrayToHexString(_ buffer: [UInt8]) -> String {
        return buffer.map { String(format: "%02X", $0) }.joined()
    }
    
    static func shortToByteArray(_ input: UInt16, bigEndian: Bool) -> [UInt8] {
        let bytes = withUnsafeBytes(of: input.bigEndian) { Array($0) }
        return bigEndian ? bytes : bytes.reversed()
    }

    static func intToByteArray(_ input: UInt32, bigEndian: Bool) -> [UInt8] {
        let bytes = withUnsafeBytes(of: input.bigEndian) { Array($0) }
        return bigEndian ? bytes : bytes.reversed()
    }

    // MARK: - Main Decoder
    
    static func decodeReceivedData(_ rc: [UInt8]) -> ReceivedStruct {
        var result = ReceivedStruct()
        
        guard rc.count >= 4 else { return result }
        
        if Array(rc.prefix(2)) == HEADER {
            result.log.append("Valid header.")
            
            // Short (2 bájt) olvasása Little Endian módon az eredeti kód alapján
            let lenBytes = Data(rc[2...3])
            let length = Int(lenBytes.withUnsafeBytes { $0.load(as: UInt16.self) })
            
            if length > 0 && Array(rc[4...5]) == RESERVED {
                result.log.append("Valid reserved word.")
                result.cmd = Array(rc[6...7])
                result.log.append("CMD: \(byteArrayToHexString(result.cmd))")
                
                result.error = rc[8]
                
                if rc.count > 9 {
                    result.data = Array(rc[9..<min(rc.count, length + 3)])
                }
                
                result.length = 4 + length
                result.log.append("Received data: \(byteArrayToHexString(result.data))")
                
                if result.error == 0x00 {
                    let crcIndex = result.length - 1
                    if crcIndex < rc.count {
                        result.crc = rc[crcIndex]
                        let crcBase = Array(rc[4..<min(rc.count, length + 3)])
                        let crcCalc = crc(crcBase)
                        
                        if result.crc == crcCalc {
                            result.log.append("Valid CRC code.")
                            result.isValid = true
                        } else {
                            result.log.append("Invalid CRC code!")
                        }
                    }
                } else {
                    result.log.append("Error code: \(result.error)")
                }
            }
        }
        return result
    }

}

