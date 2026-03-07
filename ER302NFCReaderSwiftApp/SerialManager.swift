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
    public var commandsProcessor: PROCESS = PROCESS.SINGLE_MESSAGE

    public enum PROCESS {
        case SINGLE_MESSAGE, URL_MESSAGE, TEXT_MESSAGE, VCARD_MESSAGE,
        SET_BALANCE_MESSAGE, GET_BALANCE_MESSAGE, INC_BALANCE_MESSAGE, DEC_BALANCE_MESSAGE,
        SETKEY_MESSAGE, GET_ACCESSBITS_MESSAGE
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
        // Itt jönnek be a bájtok az ER302-től (pl. AABB...)
        let hexString = data.hexEncodedString()
        appendLog("Received data: \(hexString)")
        bout.append(data)
        var currentBuffer = data
        while currentBuffer.count >= 2 && currentBuffer.prefix(2) != Data(ER302Driver.HEADER) {
            currentBuffer.removeFirst()
        }

        var result = ER302Driver.decodeReceivedData(Array(currentBuffer))
        
        while result.length > 0 {
            switch commandsProcessor {
            case .URL_MESSAGE:
                readUrlProcessCommands(result)
            case .TEXT_MESSAGE:
                readTextProcessCommands(result)
            case .VCARD_MESSAGE:
                readVCardProcessCommands(result)
            case .SET_BALANCE_MESSAGE, .GET_BALANCE_MESSAGE, .INC_BALANCE_MESSAGE, .DEC_BALANCE_MESSAGE:
                processBalanceCommads(result)
            case .SETKEY_MESSAGE:
                processPasswordKeyChange(result)
            case .GET_ACCESSBITS_MESSAGE:
                processGetAccessBits(result)
            default:
                break
            }
            
            // Puffer ürítése és frissítése
            if result.length < currentBuffer.count {
                currentBuffer = currentBuffer.advanced(by: result.length)
            } else {
                currentBuffer = Data()
            }
            
            bout = Data() // bout.reset() megfelelője
            
            if !currentBuffer.isEmpty {
                bout.append(currentBuffer)
                result = ER302Driver.decodeReceivedData(Array(currentBuffer))
            } else {
                // Set result to an empty decoded result to end the loop
                result = ER302Driver.decodeReceivedData([])
            }
            
            if !commands.isEmpty {
                if let lastCommand = commands.dequeue() { // poll() megfelelője (függ a Queue implementációdtól)
                    appendLog("Send serial data [\(lastCommand.description)]: \(ER302Driver.byteArrayToHexString(lastCommand.cmd))")
                    sendCommand(lastCommand.cmd)
                }
            }
        }
    }

    func addCommand(cmd: ER302Driver.CommandStruct) {
        commands.enqueue(cmd);
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
            // Az Arrays.copyOfRange megfelelője a Swift szeletelés (slice)
            let actualPageData = res.data.prefix(4)
            let pageHexData = Data(actualPageData).hexEncodedString()
            appendLog("Actual page (\(ulReadPageIdx)) bytes: \(pageHexData)")
            for b in actualPageData {
                // Swiftben a bájtok alapból UInt8 típusúak, így a & 0xFF elhagyható,
                // de az olvashatóság kedvéért maradhat
                if (b & 0xFF) == 0xFE {
                    appendLog(Commands.decodeNdefUri(data: Array(rawData)) ?? "Unknown URL")
                    foundURL = true
                    break
                }
                
                // Feltételezve, hogy a rawData egy Data objektum vagy hasonló puffer
                rawData.append(b)
                ulReadIdx += 1
            }

            if !foundURL && ulReadPageIdx < 40 {
                ulReadPageIdx += 1
                let command = ER302Driver.CommandStruct(
                    id: 5,
                    description: "Mifare read Ultralight",
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
            // Az Arrays.copyOfRange megfelelője a Swift szeletelés (slice)
            let actualPageData = res.data.prefix(4)
            let pageHexData = Data(actualPageData).hexEncodedString()
            appendLog("Actual page (\(ulReadPageIdx)) bytes: \(pageHexData)")
            for b in actualPageData {
                // Swiftben a bájtok alapból UInt8 típusúak, így a & 0xFF elhagyható,
                // de az olvashatóság kedvéért maradhat
                if (b & 0xFF) == 0xFE {
                    appendLog(Commands.decodeNdefText(raw: Array(rawData)))
                    foundURL = true
                    break
                }
                
                // Feltételezve, hogy a rawData egy Data objektum vagy hasonló puffer
                rawData.append(b)
                ulReadIdx += 1
            }

            if !foundURL && ulReadPageIdx < 40 {
                ulReadPageIdx += 1
                let command = ER302Driver.CommandStruct(
                    id: 5,
                    description: "Mifare read Ultralight",
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
            if let dataString = String(bytes: res.data, encoding: .ascii) {
                appendLog("Firmware version: \(dataString)")
            }
        case let res where res.cmd == ER302Driver.CMD_MIFARE_READ_BLOCK:
            var foundVCard = false
            // Az Arrays.copyOfRange megfelelője a Swift szeletelés (slice)
            let actualPageData = res.data.prefix(4)
            let pageHexData = Data(actualPageData).hexEncodedString()
            appendLog("Actual page (\(ulReadPageIdx)) bytes: \(pageHexData)")
            for b in actualPageData {
                // Swiftben a bájtok alapból UInt8 típusúak, így a & 0xFF elhagyható,
                // de az olvashatóság kedvéért maradhat
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
                    description: "Mifare read Ultralight",
                    cmd: Commands.mifareULRead(page: ulReadPageIdx)
                )
                addCommand(cmd: command)
            }
        default:
            break
        }
    }

    private func processBalanceCommads(_ decodedResult: ER302Driver.ReceivedStruct) {
        // TODO: Implement balance-related processing
        appendLog("processBalanceCommads called with length: \(decodedResult.length)")
    }

    private func processPasswordKeyChange(_ decodedResult: ER302Driver.ReceivedStruct) {
        // TODO: Implement password/key change processing
        appendLog("processPasswordKeyChange called with length: \(decodedResult.length)")
    }

    private func processGetAccessBits(_ decodedResult: ER302Driver.ReceivedStruct) {
        // TODO: Implement get access bits processing
        appendLog("processGetAccessBits called with length: \(decodedResult.length)")
    }
    
}

