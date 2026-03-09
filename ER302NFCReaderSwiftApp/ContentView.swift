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
    @State private var url = ""
    @State private var text = ""
    @State private var vcardName = ""
    @State private var vcardEmail = ""
    @State private var vcardPhone = ""
    @State private var currentKey = "FFFFFFFFFFFF"
    @State private var currentKeyType = "KeyB"
    @State private var balance = "1000"
    @State private var modification = "500"
    @State private var currentKeyForChange = "FFFFFFFFFFFF"
    @State private var newKeyForChange = "A1B2C3D4E5F6"
    @State private var keyTypeForChange = "KeyB"
    @State private var newKeyTypeForChange = "KeyB"
    @State private var keyAccessBitsForChange = "FF078069"
    @StateObject private var nfcManager: SerialManager = SerialManager()
    
    var manager = ORSSerialPortManager.shared()

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
                Text("Log / received data:")
                    .font(.caption)
                    .foregroundColor(.gray)
                ScrollViewReader { proxy in
                    ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(nfcManager.receivedLogs)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    // Ez teszi lehetővé a hosszú nyomásra előugró másolást:
                                    .textSelection(.enabled)
                                
                                // Láthatatlan pont a görgetéshez
                                Color.clear
                                    .frame(height: 1)
                                    .id("BOTTOM_ANCHOR")
                            }
                            .padding()
                        }
                        .frame(height: 250)
                        .border(Color.gray.opacity(0.5), width: 1)
                        .onChange(of: nfcManager.receivedLogs) { _, _ in
                            withAnimation {
                                proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
                            }
                        }
                }
                Picker("", selection: $selectedTab) {
                    Text("General").tag(0)
                    Text("Ultralight").tag(1)
                    Text("Micropayment").tag(2)
                    Text("Key Management").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ZStack {
                    switch selectedTab {
                    case 0 : generalTabView
                    case 1 : ultralightTabView
                    case 2 : paymentTabView
                    case 3 : keymanagementTabView
                    default:
                        Text("Other tools...")
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

    var keymanagementTabView: some View {
        VStack(spacing: 20) {
            Text("Key management commands").font(.headline)
            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Current key")
                    TextField("Current key", text: $currentKeyForChange)
                    Picker(selection: $keyTypeForChange, label: Text("Key type")) {
                        Text("KeyA").tag("KeyA")
                        Text("KeyB").tag("KeyB")
                    }
                }
                GridRow {
                    Text("New key")
                    TextField("New key", text: $newKeyForChange)
                    Picker(selection: $newKeyTypeForChange, label: Text("Key type")) {
                        Text("KeyA").tag("KeyA")
                        Text("KeyB").tag("KeyB")
                    }
                }
                GridRow {
                    Text("Key Access bits")
                    TextField("Key Access bits", text: $keyAccessBitsForChange)
                    Button("Get") {
                        
                    }
                }
                GridRow {
                    Button("Save") {
                        
                    }.padding()
                }
            }
        }
    }

    var paymentTabView: some View {
        VStack(spacing: 20) {
            Text("Micropayment commands").font(.headline)
            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Current key")
                    TextField("Current key", text: $currentKey)
                    Picker(selection: $currentKeyType, label: Text("Key type")) {
                        Text("KeyA").tag("KeyA")
                        Text("KeyB").tag("KeyB")
                    }
                }
                GridRow {
                    Text("Balance")
                    TextField("Balance", text: $balance)
                    Button("Get") {
                        
                    }
                    Button("Set") {
                        
                    }
                }
                GridRow {
                    Text("Modification")
                    TextField("Modification", text: $modification)
                    Button("Increase") {
                        
                    }
                    Button("Decrease") {
                        
                    }
                }
            }
        }
    }
    
    var generalTabView: some View {
        VStack(spacing: 20) {
            Text("General commands").font(.headline)
            
            Button(action: {
                let bytes = Commands.beep(msec: 100)
                nfcManager.clearLog()
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
                        nfcManager.clearLog()
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
                        let cmd = Commands.buildCommand(cmd: hexToBytes(commandHexString) ?? [], data: hexToBytes(paramHexString) ?? [])
                        hexString = ER302Driver.byteArrayToHexString(cmd)
                    }
                }
            }
            
        }
        .padding()
    }
    
    var ultralightTabView: some View {
        VStack(spacing: 20) {
            Text("Ultralight commands").font(.headline)
            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("URL on Ultralight:")
                    TextField("URL", text: $url)
                    Button("Upload") {
                        uploadURL()
                    }
                    Button("Download") {
                        downloadURL()
                    }
                }
                GridRow {
                    Text("Text on Ultralight:")
                    TextField("Text", text: $text)
                    Button("Upload") {
                        uploadText()
                    }
                    Button("Download") {
                        downloadText()
                    }
                }
                Text("VCard on Ultralight:")
                    .padding()
                GridRow {                    
                    Text("Name:")
                    TextField("Name", text: $vcardName)
                    Text("email:")
                    TextField("email", text: $vcardEmail)
                    Text("phone:")
                    TextField("phone", text: $vcardPhone)
                    Button("Upload") {
                        uploadVCard()
                    }
                    Button("Download") {
                        downloadVCard()
                    }
                }
            }
        }
    }
    
    func downloadURL() {
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.URL_MESSAGE
        nfcManager.rawData = Data()
        nfcManager.ulReadPageIdx = 4
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "Firmware version", cmd: Commands.readFirmware()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare request", cmd: Commands.mifareRequest()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare anticolision", cmd: Commands.mifareAnticolision()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight select", cmd: Commands.mifareULSelect()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight select", cmd: Commands.mifareULRead(page: nfcManager.ulReadPageIdx)));
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func uploadURL() {
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SINGLE_MESSAGE
        nfcManager.sendCommand(Commands.beep(msec: 50))
        Thread.sleep(forTimeInterval: 1)
        sendCommonULCommands()
        let dataToWrite = Commands.createNdefUrlMessage(url: url)
        for i in stride(from: 0, to: dataToWrite!.count, by: 4) {
            // Kiszámoljuk a hátralévő bájtokat a chunk méretéhez
            let remaining = dataToWrite!.count - i
            let chunkSize = min(4, remaining)
            
            // Szeletelés (Array slice) és feltöltés 0-kkal, ha 4-nél rövidebb a maradék
            var chunk = Array(dataToWrite![i..<i + chunkSize])
            if chunk.count < 4 {
                chunk.append(contentsOf: Array(repeating: 0, count: 4 - chunk.count))
            }
            
            let page = UInt8(4 + (i / 4))
            let pcmd = Commands.mifareULWrite(page: page, data: chunk)
            
            nfcManager.sendCommand(pcmd)
            
            // 100ms várakozás az írások között
            Thread.sleep(forTimeInterval: 0.5)
        }
        nfcManager.sendCommand(Commands.cmdHltA())
    }

    func downloadText() {
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.TEXT_MESSAGE
        nfcManager.rawData = Data()
        nfcManager.ulReadPageIdx = 4
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "Firmware version", cmd: Commands.readFirmware()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare request", cmd: Commands.mifareRequest()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare anticolision", cmd: Commands.mifareAnticolision()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight select", cmd: Commands.mifareULSelect()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight read page", cmd: Commands.mifareULRead(page: nfcManager.ulReadPageIdx)));
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func uploadText() {
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SINGLE_MESSAGE
        nfcManager.sendCommand(Commands.beep(msec: 50))
        Thread.sleep(forTimeInterval: 1)
        sendCommonULCommands()
        let dataToWrite = Commands.createNdefTextMessage(text: text)
        for i in stride(from: 0, to: dataToWrite.count, by: 4) {
            // Kiszámoljuk a hátralévő bájtokat a chunk méretéhez
            let remaining = dataToWrite.count - i
            let chunkSize = min(4, remaining)
            
            // Szeletelés (Array slice) és feltöltés 0-kkal, ha 4-nél rövidebb a maradék
            var chunk = Array(dataToWrite[i..<i + chunkSize])
            if chunk.count < 4 {
                chunk.append(contentsOf: Array(repeating: 0, count: 4 - chunk.count))
            }
            
            let page = UInt8(4 + (i / 4))
            let pcmd = Commands.mifareULWrite(page: page, data: chunk)
            
            nfcManager.sendCommand(pcmd)
            
            // 100ms várakozás az írások között
            Thread.sleep(forTimeInterval: 0.5)
        }
        nfcManager.sendCommand(Commands.cmdHltA())
    }

    func downloadVCard() {
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.VCARD_MESSAGE
        nfcManager.rawData = Data()
        nfcManager.ulReadPageIdx = 4
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "Firmware version", cmd: Commands.readFirmware()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare request", cmd: Commands.mifareRequest()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare anticolision", cmd: Commands.mifareAnticolision()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight select", cmd: Commands.mifareULSelect()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight read page", cmd: Commands.mifareULRead(page: nfcManager.ulReadPageIdx)));
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func uploadVCard() {
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SINGLE_MESSAGE
        nfcManager.sendCommand(Commands.beep(msec: 50))
        Thread.sleep(forTimeInterval: 1)
        sendCommonULCommands()
        let dataToWrite = Commands.createNdefVCardMessage(name: vcardName, phone: vcardPhone, email: vcardEmail)
        for i in stride(from: 0, to: dataToWrite.count, by: 4) {
            // Kiszámoljuk a hátralévő bájtokat a chunk méretéhez
            let remaining = dataToWrite.count - i
            let chunkSize = min(4, remaining)
            
            // Szeletelés (Array slice) és feltöltés 0-kkal, ha 4-nél rövidebb a maradék
            var chunk = Array(dataToWrite[i..<i + chunkSize])
            if chunk.count < 4 {
                chunk.append(contentsOf: Array(repeating: 0, count: 4 - chunk.count))
            }
            
            let page = UInt8(4 + (i / 4))
            let pcmd = Commands.mifareULWrite(page: page, data: chunk)
            
            nfcManager.sendCommand(pcmd)
            
            // 100ms várakozás az írások között
            Thread.sleep(forTimeInterval: 0.5)
        }
        nfcManager.sendCommand(Commands.cmdHltA())
    }

    func sendCommonULCommands() {
        nfcManager.sendCommand(Commands.mifareRequest())
        Thread.sleep(forTimeInterval: 1)
        nfcManager.sendCommand(Commands.mifareAnticolision())
        Thread.sleep(forTimeInterval: 1)
        nfcManager.sendCommand(Commands.mifareULSelect())
        Thread.sleep(forTimeInterval: 1)
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

