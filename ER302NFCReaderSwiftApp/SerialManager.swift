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
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        appendLog("Disconnected.")
    }
    // MARK: - ORSSerialPortDelegate

    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        // Itt jönnek be a bájtok az ER302-től (pl. AABB...)
        let hexString = data.map { String(format: "%02X", $0) }.joined()
        appendLog("Received data: \(hexString)")
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
    
}
