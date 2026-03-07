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

    public static func mifareRequest() -> [UInt8] {
        let data: [UInt8] = [0x52]
        let result = buildCommand(cmd: ER302Driver.CMD_MIFARE_REQUEST, data: data)
        return result
    }
    
    // MARK: - MIFARE Commands

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

