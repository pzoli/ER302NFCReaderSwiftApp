//
//  ContentView.swift
//  Homework4ER302
//
//  Created by Papp Zoltán on 2026. 02. 27..
//

import SwiftUI
import ORSSerial
internal import Combine

struct ContentView: View {
    @State private var data: String = ""
    @State private var selectedPort = "none"
    @State private var selectedTab = 0
    @State private var hexString = ""
    @State private var messageForDecode = ""
    @State private var commandHexString = ""
    @State private var paramHexString = ""
    @StateObject private var nfcManager: SerialManager = SerialManager()

    var manager = ORSSerialPortManager.shared()
    private var isConnected: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Picker(selection: $selectedPort, label: Text("Serial Port")) {
                    ForEach(self.manager.availablePorts, id: \.self.path) {
                        Text($0.path)
                    }
                }.id(self.manager.availablePorts)
            
                let buttonLabel = (nfcManager.serialPort?.isOpen ?? false) ? "Disconnect" : "Connect"
                Button(buttonLabel) {
                    if nfcManager.serialPort?.isOpen ?? false {
                            // Ha nyitva van, zárjuk be
                            nfcManager.serialPort?.close()
                            // Frissítsük a UI-t (az ORSSerialPort nem mindig küld azonnali értesítést a zárásról)
                            nfcManager.objectWillChange.send()
                        } else {
                            // Ha zárva van, nyissuk meg
                            if !selectedPort.isEmpty {
                                nfcManager.setupPort(path: selectedPort)
                            }
                        }
                }
            }
            VStack(alignment: .leading) {
                Text("Log / Beérkező adatok:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextEditor(text: $nfcManager.receivedLogs)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 250)
                    .border(Color.gray.opacity(0.5), width: 1)
                Picker("", selection: $selectedTab) {
                            Text("General").tag(0)
                            Text("Ultralight").tag(1)
                            Text("Micropayment").tag(2)
                        }
                        .pickerStyle(.segmented) // Ettől lesz "fül" kinézete
                        .padding()

                        // 4. Az aktuális fül tartalma (TabView helyett egy Switch vagy If)
                        ZStack {
                            switch selectedTab {
                            case 0 : generalTabView
                            case 1 : advancedTabView
                            default:
                                Text("Other tools...")
                                Button("Test conversation") {
                                }
                                .buttonStyle(.borderedProminent) // Stílus hozzáadása
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.windowBackgroundColor))
            }
            .padding()
        }
        
    }
    
    private func appendLog(_ text: String) {
        nfcManager.receivedLogs += text + "\n"
    }

    var generalTabView: some View {
        VStack(spacing: 20) {
            Text("General commands").font(.headline)
            
            Button(action: {
                let bytes = beep(msec: 100)
                nfcManager.sendCommand(bytes)
            }) {
                Label("Send Beep", systemImage: "speaker.wave.3")
                    //.frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!(nfcManager.serialPort?.isOpen ?? false))
            
            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Hex String")
                    TextField("Hex String", text: $hexString)
                    Button("Send") {
                        nfcManager.sendCommand(hexToBytes(hexString) ?? [])
                    }
                }
                GridRow {
                    Text("Message")
                    TextField("Message", text: $messageForDecode)
                    Button("Decode") {
                        let response = ER302Driver.decodeReceivedData(hexToBytes(messageForDecode) ?? [])
                        appendLog(response.asJSONString())
                    }
                }
                GridRow {
                    Text("Command:")
                    TextField("Command", text: $commandHexString)
                    Text("Params:")
                    TextField("Params", text: $paramHexString)

                    Button("Encode") {
                        let cmd = buildCommand(cmd: hexToBytes(commandHexString) ?? [], data: hexToBytes(paramHexString) ?? [])
                        hexString = ER302Driver.byteArrayToHexString(cmd)
                    }
                }
            }

        }
        .padding()
    }
    
    var advancedTabView: some View {
        VStack(spacing: 20) {
            Text("Ultralight commands").font(.headline)
        }
    }
    
    private func beep(msec: UInt8) -> [UInt8] {
        let data: [UInt8] = [msec]
        let result = buildCommand(cmd: ER302Driver.CMD_BEEP, data: data)
        return result
    }
    
    private func buildCommand(cmd: [UInt8], data: [UInt8]) -> [UInt8] {
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

func hexToBytes(_ hex: String) -> [UInt8]? {
    let chars = Array(hex)
    return stride(from: 0, to: chars.count, by: 2).compactMap {
        UInt8(String(chars[$0..<$0+2]), radix: 16)
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhX", $0) }.joined()
    }
}


#Preview {
    ContentView()
}
