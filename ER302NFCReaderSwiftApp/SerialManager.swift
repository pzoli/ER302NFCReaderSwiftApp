//
//  NFCReaderManager.swift
//  Homework4ER302
//
//  Created by Papp Zoltán on 2026. 02. 28..
//

import Foundation
import ORSSerial
internal import Combine

class SerialManager: NSObject, ORSSerialPortDelegate, ObservableObject {
    var serialPort: ORSSerialPort?
    
    @Published var receivedLogs: String = ""
    private var lastCommand: ER302Driver.CommandStruct? = nil;
    private var commands = Queue<ER302Driver.CommandStruct>()
    
    private var state = 0
    public var ulReadPageIdx: UInt8 = 4
    public var ulReadIdx = 0
    public var rawData = Data()
    private var bout = Data()
    private var currentUID = [UInt8]()
    public var currentSector: UInt8 = 0
    public var currentBlock: UInt8 = 0
    public var currentKey = ""
    public var newKey = ""
    public var lastReadedBlock: [UInt8] = []
    public var isCurrentKeyA = false
    public var isNewKeyA = false
    public var balance: UInt32 = 0
    public var modification: UInt32 = 0
    public var accessBits = ""
    public var commandsProcessor: PROCESS = PROCESS.SINGLE_MESSAGE

    public enum PROCESS {
        case SINGLE_MESSAGE, URL_MESSAGE, TEXT_MESSAGE, VCARD_MESSAGE, VCARD_CLASSIC_MESSAGE,
        SET_BALANCE_MESSAGE, GET_BALANCE_MESSAGE, INC_BALANCE_MESSAGE, DEC_BALANCE_MESSAGE,
        SETKEY_MESSAGE, GET_ACCESSBITS_MESSAGE, WRITE_VCARD_CLASSIC_MESSAGE
    };
    
    func setupPort(path: String) {
        // Az ER302 alapértelmezett baud rate-je általában 115200 vagy 9600
        serialPort = ORSSerialPort(path: path)
        serialPort?.baudRate = 115200 //9600
        serialPort?.numberOfDataBits = 8
        serialPort?.numberOfStopBits = 1
        serialPort?.parity = .none
        serialPort?.dtr = false
        serialPort?.rts = false
        serialPort?.delegate = self
        serialPort?.open()
        
        appendLog("Connected to device at path: \(path)")
    }

    func sendCommand(_ command: [UInt8]) {
        if ((serialPort?.isOpen) != nil) {
            let data = Data(command)
            serialPort?.send(data)
            appendLog("Sent data: \(data.hexEncodedString())")
        }
    }

    private func appendLog(_ text: String) {
            DispatchQueue.main.async {
                self.receivedLogs += text + "\n"
            }
    }
    
    public func clearLog() {
            DispatchQueue.main.async {
                self.receivedLogs = ""
            }
    }
        
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        appendLog("Disconnected.")
    }
    
    // MARK: - ORSSerialPortDelegate

    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        let hexString = data.hexEncodedString()
        appendLog("Received data: \(hexString)")
        bout.append(data)
        var currentBuffer = data
        while currentBuffer.count >= 2 && currentBuffer.prefix(2) != Data(ER302Driver.HEADER) {
            currentBuffer.removeFirst()
        }

        var result = ER302Driver.decodeReceivedData(Array(currentBuffer))
        
        while result.length > 0 {
            switch commandsProcessor { //Better way is a method pointer instead switch
            case .URL_MESSAGE:
                readUrlProcessCommands(result)
            case .TEXT_MESSAGE:
                readTextProcessCommands(result)
            case .VCARD_MESSAGE:
                readVCardProcessCommands(result)
            case .VCARD_CLASSIC_MESSAGE:
                readVCardClassicProcessCommands(result)
            case .SET_BALANCE_MESSAGE, .GET_BALANCE_MESSAGE, .INC_BALANCE_MESSAGE, .DEC_BALANCE_MESSAGE:
                processBalanceCommads(result)
            case .SETKEY_MESSAGE:
                processPasswordKeyChange(result)
            case .GET_ACCESSBITS_MESSAGE:
                processGetAccessBits(result)
            case .WRITE_VCARD_CLASSIC_MESSAGE:
                processVCardWriteClassic(result)
            default:
                break
            }
            
            if result.length < currentBuffer.count {
                currentBuffer = currentBuffer.advanced(by: result.length)
            } else {
                currentBuffer = Data()
            }
            
            bout = Data()
            
            if !currentBuffer.isEmpty {
                bout.append(currentBuffer)
                result = ER302Driver.decodeReceivedData(Array(currentBuffer))
            } else {
                result = ER302Driver.decodeReceivedData([])
            }
            
            if !commands.isEmpty {
                if let lastCommand = commands.dequeue() {
                    appendLog("Send serial data [\(lastCommand.description)]: \(ER302Driver.byteArrayToHexString(lastCommand.cmd))")
                    sendCommand(lastCommand.cmd)
                }
            }
        }
    }

    func addCommand(cmd: ER302Driver.CommandStruct) {
        commands.enqueue(cmd);
    }
    func pushCommand(cmd: ER302Driver.CommandStruct) {
        commands.push(cmd);
    }
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.serialPort = nil
        appendLog("Reader removed.")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        appendLog("Error: \(error.localizedDescription)")
    }
    
    deinit {
        serialPort?.close()
        serialPort?.delegate = nil
    }
    
    // MARK: - Command Processing Stubs

    private func readUrlProcessCommands(_ decodedResult: ER302Driver.ReceivedStruct) {
        appendLog("readUrlProcessCommands called with length: \(decodedResult.length)")
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_READ_FW_VERSION:
            if let dataString = String(bytes: res.data, encoding: .utf8) {
                appendLog("Firmware version: \(dataString)")
            }
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BLOCK:
            var foundURL = false
            let actualPageData = res.data.prefix(4)
            let pageHexData = Data(actualPageData).hexEncodedString()
            appendLog("Actual page (\(ulReadPageIdx)) bytes: \(pageHexData)")
            for b in actualPageData {
                if (b & 0xFF) == 0xFE {
                    appendLog(Commands.decodeNdefUri(data: Array(rawData)) ?? "Unknown URL")
                    foundURL = true
                    break
                }
                
                rawData.append(b)
                ulReadIdx += 1
            }

            if !foundURL && ulReadPageIdx < 40 {
                ulReadPageIdx += 1
                let command = ER302Driver.CommandStruct(
                    id: 5,
                    description: "MiFare read Ultralight",
                    cmd: Commands.mifareULRead(page: ulReadPageIdx)
                )
                addCommand(cmd: command)
            }
        default:
            break
        }
    }

    private func readTextProcessCommands(_ decodedResult: ER302Driver.ReceivedStruct) {
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_READ_FW_VERSION:
            if let dataString = String(bytes: res.data, encoding: .utf8) {
                appendLog("Firmware version: \(dataString)")
            }
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BLOCK:
            var foundURL = false
            let actualPageData = res.data.prefix(4)
            let pageHexData = Data(actualPageData).hexEncodedString()
            appendLog("Actual page (\(ulReadPageIdx)) bytes: \(pageHexData)")
            for b in actualPageData {
                if (b & 0xFF) == 0xFE {
                    appendLog(Commands.decodeNdefText(raw: Array(rawData)))
                    foundURL = true
                    break
                }
                
                rawData.append(b)
                ulReadIdx += 1
            }

            if !foundURL && ulReadPageIdx < 40 {
                ulReadPageIdx += 1
                let command = ER302Driver.CommandStruct(
                    id: 5,
                    description: "MiFare read Ultralight",
                    cmd: Commands.mifareULRead(page: ulReadPageIdx)
                )
                addCommand(cmd: command)
            }
        default:
            break
        }
    }

    private func readVCardProcessCommands(_ decodedResult: ER302Driver.ReceivedStruct) {
        appendLog("readVCardProcessCommands called with length: \(decodedResult.length)")
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_READ_FW_VERSION:
            if let dataString = String(bytes: res.data, encoding: .utf8) {
                appendLog("Firmware version: \(dataString)")
            }
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BLOCK:
            var foundVCard = false
            let actualPageData = res.data.prefix(4)
            let pageHexData = Data(actualPageData).hexEncodedString()
            appendLog("Actual page (\(ulReadPageIdx)) bytes: \(pageHexData)")
            for b in actualPageData {
                if (b & 0xFF) == 0xFE {
                    appendLog(Commands.decodeNdefVCard(raw: rawData))
                    foundVCard = true
                    break
                }
                
                // Feltételezve, hogy a rawData egy Data objektum vagy hasonló puffer
                rawData.append(b)
                ulReadIdx += 1
            }

            if !foundVCard && ulReadPageIdx < 40 {
                ulReadPageIdx += 1
                let command = ER302Driver.CommandStruct(
                    id: ulReadIdx,
                    description: "MiFare read Ultralight",
                    cmd: Commands.mifareULRead(page: ulReadPageIdx)
                )
                addCommand(cmd: command)
            }
        default:
            break
        }
    }

    private func processBalanceCommads(_ decodedResult: ER302Driver.ReceivedStruct) {
        appendLog("processBalanceCommads called with length: \(decodedResult.length)")
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_MIFARE_REQUEST:
            let command = ER302Driver.CommandStruct(
                id: 4,
                description: "MiFare Anticollision",
                cmd: Commands.mifareAnticolision()
            )
            addCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_ANTICOLISION:
            appendLog("MiFare anticollision received UID: " + Data(res.data).hexEncodedString())
            currentUID = res.data
            let command = ER302Driver.CommandStruct(
                id: 5,
                description: "MiFare Select",
                cmd: Commands.mifareSelect(select: currentUID)
            )
            addCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_SELECT:
            let command = ER302Driver.CommandStruct(
                id: 6,
                description: "MiFare Auth2",
                cmd: Commands.auth2(sector: currentSector, keyString: currentKey, keyA: isCurrentKeyA)
            )
            addCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_AUTH2:
            switch commandsProcessor {
            case PROCESS.GET_BALANCE_MESSAGE:
                let command = ER302Driver.CommandStruct(
                    id: 7,
                    description: "MiFare get balance",
                    cmd: Commands.readBalance(sector: currentSector, block: currentBlock)
                )
                addCommand(cmd: command)
            case .SET_BALANCE_MESSAGE:
                let command = ER302Driver.CommandStruct(
                    id: 7,
                    description: "MiFare set balance",
                    cmd: Commands.initBalance(sector: currentSector, block: currentBlock, i: balance)
                )
                addCommand(cmd: command)
            case .INC_BALANCE_MESSAGE:
                let command = ER302Driver.CommandStruct(
                    id: 7,
                    description: "MiFare increment balance",
                    cmd: Commands.incBalance(sector: currentSector, block: currentBlock, i: modification)
                )
                addCommand(cmd: command)
            case .DEC_BALANCE_MESSAGE:
                let command = ER302Driver.CommandStruct(
                    id: 7,
                    description: "MiFare decrement balance",
                    cmd: Commands.decBalance(sector: currentSector, block: currentBlock, i: modification)
                )
                addCommand(cmd: command)
            default:
                break
            }
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BALANCE:
            if (res.error == 0x00) {
                let readedBalance = ER302Driver.byteArrayToInteger(src: res.data, bigEndian: false)
                appendLog("MiFare read balance: \(readedBalance)")
            } else {
                appendLog("MiFare read balance error: \(res.error)")
            }
            
        case let res where res.cmd == ER302Driver.CMD_MIFARE_INCREMENT:
            appendLog("MiFare balance modification: \(decodedResult.error)")
        case let res where res.cmd == ER302Driver.CMD_MIFARE_DECREMENT:
            appendLog("MiFare balance modification: \(decodedResult.error)")
        default:
            break
        }
    }

    private func processPasswordKeyChange(_ decodedResult: ER302Driver.ReceivedStruct) {
        appendLog("processPasswordKeyChange called with length: \(decodedResult.length)")
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_MIFARE_ANTICOLISION:
            appendLog("MiFare anticollision received UID: " + Data(res.data).hexEncodedString())
            currentUID = res.data
            let command = ER302Driver.CommandStruct(
                id: 3,
                description: "MiFare Select",
                cmd: Commands.mifareSelect(select: currentUID)
            )
            pushCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_SELECT:
            authenticate(currentSector)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_AUTH2:
            let command = ER302Driver.CommandStruct(
                id: 3,
                description: "MiFare read block",
                cmd: Commands.readBlock(sector: currentSector, block: 3)
            )
            addCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BLOCK:
            if (res.error != 0) {
                appendLog("Read error \(res.error)")
                return
            }
            lastReadedBlock = res.data
            let accessBitsBlock = hexToBytes(accessBits)
            let newKeyBlock = hexToBytes(newKey)
            for i in 0..<accessBitsBlock!.count {
                lastReadedBlock[6 + i] = accessBitsBlock![i]
            }
            let offset: Int = isNewKeyA ? 0 : 10
            for i in 0..<newKeyBlock!.count {
                lastReadedBlock[offset + i] = newKeyBlock![i]
            }
            let command = ER302Driver.CommandStruct(
                id: 4,
                description: "MiFare Select",
                cmd: Commands.writeFullBlock(sector: currentSector, block: 3, dataBlock: lastReadedBlock)
            )
            appendLog("Incoming block: \(Data(res.data).hexEncodedString()), new block: \(Data(lastReadedBlock).hexEncodedString())")
            addCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_WRITE_BLOCK:
            appendLog("Write block: \(res.error)")
            addCommand(cmd: ER302Driver.CommandStruct(id: 6, description: "MiFare HltA", cmd: Commands.cmdHltA()))
        default :
            break
        }
    }

    private func processGetAccessBits(_ decodedResult: ER302Driver.ReceivedStruct) {
        appendLog("processGetAccessBits called with length: \(decodedResult.length)")
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_MIFARE_ANTICOLISION:
            appendLog("MiFare anticollision received UID: " + Data(res.data).hexEncodedString())
            currentUID = res.data
            let command = ER302Driver.CommandStruct(
                id: 3,
                description: "MiFare Select",
                cmd: Commands.mifareSelect(select: currentUID)
            )
            pushCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_SELECT:
            authenticate(currentSector)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BLOCK:
            if (res.error != 0) {
                appendLog("Error reading block: \(res.error)")
                return
            }
            let blockHexString = Data(res.data).hexEncodedString()
            if (blockHexString.count < 20) {
                appendLog("Access bits response lenght is smaller then 20: \(blockHexString)")
                return
            }
            let accessBitsSclice = blockHexString[12..<20]
            accessBits = String(accessBitsSclice)
            addCommand(cmd: ER302Driver.CommandStruct(id: 6, description: "MiFare HltA", cmd: Commands.cmdHltA()))
        case let res where res.cmd == ER302Driver.CMD_MIFARE_HLTA:
            appendLog("Access bits: \(accessBits)")
        default :
            break
        }
    }

    func authenticate(_ sector: UInt8) {
        let command = ER302Driver.CommandStruct(
            id: 4,
            description: "MiFare Auth",
            cmd: Commands.auth2(sector: currentSector, keyString: currentKey, keyA: isCurrentKeyA)
        )
        pushCommand(cmd: command)
    }

    private func readVCardClassicProcessCommands(_ decodedResult: ER302Driver.ReceivedStruct) {
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_MIFARE_ANTICOLISION:
            appendLog("MiFare anticollision received UID: " + Data(res.data).hexEncodedString())
            currentUID = res.data
            let command = ER302Driver.CommandStruct(
                id: 3,
                description: "MiFare Select",
                cmd: Commands.mifareSelect(select: currentUID)
            )
            pushCommand(cmd: command)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_SELECT:
            authenticate(currentSector)
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BLOCK:
            var foundVCard = false
            let actualPageData = res.data
            let pageHexData = Data(actualPageData).hexEncodedString()
            appendLog("Actual page (\(currentSector)/\(currentBlock)) bytes: \(pageHexData)")
            for b in actualPageData {
                if (b & 0xFF) == 0xFE {
                    appendLog(Commands.decodeNdefVCard(raw: rawData))
                    foundVCard = true
                    break
                }
                rawData.append(b)
            }

            if res.error == 0 && !foundVCard && currentSector < 40 {
                currentBlock += 1
                if (currentBlock == 3) {
                    currentBlock = 0
                    currentSector += 1
                    authenticate(currentSector)
                }
                let command = ER302Driver.CommandStruct(
                    id: ulReadIdx,
                    description: "MiFare read block",
                    cmd: Commands.readBlock(sector: currentSector, block: currentBlock)
                )
                addCommand(cmd: command)
            }
        default :
            break
        }
    }
    
    private func processVCardWriteClassic(_ decodedResult: ER302Driver.ReceivedStruct) {
        appendLog("processVCardWriteClassic called with length: \(decodedResult.length)")
        switch decodedResult {
        case let res where res.cmd == ER302Driver.CMD_MIFARE_ANTICOLISION:
            appendLog("MiFare anticollision received UID: " + Data(res.data).hexEncodedString())
            currentUID = res.data
            let command = ER302Driver.CommandStruct(
                id: 3,
                description: "MiFare Select",
                cmd: Commands.mifareSelect(select: currentUID)
            )
            pushCommand(cmd: command)
        default :
            break
        }
    }
    
}

