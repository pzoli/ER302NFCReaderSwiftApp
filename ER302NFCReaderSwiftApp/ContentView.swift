//
//  ContentView.swift
//  Homework4ER302
//
//  Created by Papp Zoltán on 2026. 02. 27..
//

import SwiftUI
import ORSSerial
internal import Combine
internal import UniformTypeIdentifiers

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
    @State private var keyForClassic = "FFFFFFFFFFFF"
    @State private var keyTypeForClassic = "KeyB"
    @State private var currentKey = "FFFFFFFFFFFF"
    @State private var currentKeyType = "KeyB"
    @State private var balance: UInt32 = 1000
    @State private var currentBlock = "0"
    @State private var currentSector: UInt8 = 5
    @State private var modification: UInt32 = 500
    @State private var currentSectorForChange: UInt8 = 5
    @State private var currentKeyForChange = "FFFFFFFFFFFF"
    @State private var newKeyForChange = "A1B2C3D4E5F6"
    @State private var keyTypeForChange = "KeyB"
    @State private var newKeyTypeForChange = "KeyB"
    @State private var keyAccessBitsForChange = "FF078069"

    @State private var people: [Person] = []
    @State private var selectedPersonID: Person.ID?
    
    @State private var isImporting: Bool = false
    @State private var filename: String = "No file selected"
    @State private var showAlert = false
    @FocusState private var isTextFieldFocused: Bool
    
    @StateObject private var nfcManager: SerialManager = SerialManager()

    private var selectedPersonIndex: Int? {
            people.firstIndex(where: { $0.id == selectedPersonID })
        }

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
                        nfcManager.serialPort?.close()
                        nfcManager.objectWillChange.send()
                    } else {
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
                    Text("Classic").tag(2)
                    Text("Micropayment").tag(3)
                    Text("Key Management").tag(4)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ZStack {
                    switch selectedTab {
                    case 0 : generalTabView
                    case 1 : ultralightTabView
                    case 2 : classicTabView
                    case 3 : paymentTabView
                    case 4 : keymanagementTabView
                    default:
                        Text("Other tools...")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .padding()
        }.frame(minWidth: 800,
                maxWidth: .infinity,
                minHeight: 600,
                maxHeight: .infinity)
        
    }
    
    private func appendLog(_ text: String) {
        nfcManager.receivedLogs += text + "\n"
    }
    
    var keymanagementTabView: some View {
        VStack(spacing: 20) {
            Text("Key management commands").font(.headline)
            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Current sector")
                    TextField("Current sector", value: $currentSectorForChange, format: .number)
                }
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
                        getAccessBits()
                    }
                }
                GridRow {
                    Button("Save") {
                        saveNewPassKey()
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
                    Text("Current sector")
                    TextField("Current sector", value: $currentSector, format: .number)
                    Picker("Current block", selection: $currentBlock) {
                        ForEach(0..<3) { number in
                            Text("\(number)").tag("\(number)")
                        }
                    }.pickerStyle(.menu)
                }
                GridRow {
                    Text("Balance")
                    TextField("Balance", value: $balance, format: .number)
                    Button("Get") {
                        getBalance()
                    }
                    Button("Set") {
                        setBalance()
                    }
                }
                GridRow {
                    Text("Modification")
                    TextField("Modification", value: $modification, format: .number)
                    Button("Increase") {
                        incBalance()
                    }
                    Button("Decrease") {
                        decBalance()
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
                        let cmd = hexToBytes(hexString) ?? []
                        if (cmd.isEmpty) {
                            showAlert.toggle()
                            return
                        }
                        nfcManager.sendCommand(cmd)
                    }.alert("Error!", isPresented: $showAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Not a valid hex string!")
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
    
    var classicTabView: some View {
        VStack(spacing: 20) {
            if people.isEmpty {
                ContentUnavailableView("No data", systemImage: "doc.text.magnifyingglass", description: Text("Import a CSV file to see them here."))
            } else {
                // SwiftUI Táblázat 3 oszloppal
                Table(people, selection: $selectedPersonID) {
                    TableColumn("Name", value: \.name)
                    TableColumn("E-mail", value: \.email)
                    TableColumn("Phone", value: \.phone)
                }
            }
            
            Divider()
            VStack(spacing: 20) {
                Text(filename)
                    .font(.headline)
                HStack {
                    Button("Add person") {
                        let item = Person(name: "", email: "", phone: "")
                        people.append(item)
                        selectedPersonID = item.id
                        isTextFieldFocused = true
                    }
                    Button("Delete person") {
                        if let id = selectedPersonID {
                            people.removeAll { $0.id == id }
                            selectedPersonID = nil
                        }
                    } .disabled(selectedPersonID == nil)
                    Button("Choose a CSV file") {
                        isImporting = true
                    }
                }
            }
            .padding()
            // Itt történik a varázslat:
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText], // Itt adhatod meg a típust (pl. .png, .pdf, .item)
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let selectedUrl = urls.first {
                        self.filename = selectedUrl.lastPathComponent
                        self.people = parseCSV(at: selectedUrl)
                        print("Kiválasztott útvonal: \(selectedUrl.path(percentEncoded: false))")
                    }
                case .failure(let error):
                    print("Hiba történt: \(error.localizedDescription)")
                }
            }
            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Actual Key:")
                    TextField("Key", text: $keyForClassic)
                    Picker(selection: $keyTypeForClassic, label: Text("Key type")) {
                        Text("KeyA").tag("KeyA")
                        Text("KeyB").tag("KeyB")
                    }
                }
                Text("VCard data:")
                if let idx = selectedPersonIndex {
                    GridRow {
                        Text("Name:")
                        TextField("Name", text: $people[idx].name).focused($isTextFieldFocused)
                        Text("email:")
                        TextField("email", text: $people[idx].email)
                        Text("phone:")
                        TextField("phone", text: $people[idx].phone)
                        Button("Upload") {
                            uploadVCardClassic()
                        }
                        Button("Download") {
                            downloadVCardClassic()
                        }
                    }
                } else {
                    GridRow {
                        Text("Name:")
                        TextField("Name", text: .constant(""))
                            .disabled(true)
                        Text("email:")
                        TextField("email", text: .constant(""))
                            .disabled(true)
                        Text("phone:")
                        TextField("phone", text: .constant(""))
                            .disabled(true)
                        Button("Upload") {
                            uploadVCardClassic()
                        }
                        .disabled(true)
                        Button("Download") {
                            downloadVCardClassic()
                        }
                    }
                }
            }
        }
    }
    
    func downloadURL() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
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
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SINGLE_MESSAGE
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
            
            add(4,"MiFare UL Write page: \(page)",pcmd)
        }
        add(5,"HltA",Commands.cmdHltA())
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func downloadText() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
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
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SINGLE_MESSAGE
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
            
            add(4,"MiFare write page: \(page)",pcmd)
        }
        add(5, "HltA", Commands.cmdHltA())
        nfcManager.sendCommand(Commands.beep(msec:50))
    }
    
    func downloadVCard() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.VCARD_MESSAGE
        nfcManager.rawData = Data()
        nfcManager.ulReadPageIdx = 4
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "Firmware version", cmd: Commands.readFirmware()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare request", cmd: Commands.mifareRequest()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare anticolision", cmd: Commands.mifareAnticolision()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight select", cmd: Commands.mifareULSelect()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare Ultralight read page", cmd: Commands.mifareULRead(page: nfcManager.ulReadPageIdx)))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func downloadVCardClassic() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.VCARD_CLASSIC_MESSAGE
        nfcManager.rawData = Data()
        nfcManager.currentSector = 1
        nfcManager.currentBlock = 0
        nfcManager.currentKey = keyForClassic
        nfcManager.isCurrentKeyA = keyTypeForClassic == "KeyA"
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "Firmware version", cmd: Commands.readFirmware()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare request", cmd: Commands.mifareRequest()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare anticolision", cmd: Commands.mifareAnticolision()));
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:4, description: "MiFare read block", cmd: Commands.readBlock(sector: nfcManager.currentSector, block: nfcManager.currentBlock)))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func uploadVCard() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SINGLE_MESSAGE
        
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
            
            add(4,"UL Write page: \(page)",pcmd)
        }
        add(5,"MiFare HltA",Commands.cmdHltA())
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func add(_ id: Int, _ description: String, _ cmd: [UInt8]) {
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id: id, description: description, cmd: cmd))
    }

    func uploadVCardClassic() {
        if selectedPersonIndex == nil || nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.WRITE_VCARD_CLASSIC_MESSAGE
        
        // Build NDEF vCard payload using existing helper
        let index = selectedPersonIndex!
        let ndef = Commands.createNdefVCardMessage(name: people[index].name, phone: people[index].phone, email: people[index].email)
        
        func authenticate(sector: UInt8) {
            let useKeyA = (keyTypeForClassic == "KeyA")
            add(4, "Auth sector \(sector)", Commands.auth2(sector: sector, keyString: keyForClassic, keyA: useKeyA))
        }
        
        // Card activation
        add(1, "MiFare Request", Commands.mifareRequest())
        add(2, "MiFare Anticolision", Commands.mifareAnticolision())
        
        // Prepare MAD (Sector 0 blocks 1 & 2) for NDEF AID per NFC Forum Type 2/Classic mapping
        // MAD1 block (sector 0, block 1): set NDEF app (0x10) at position for sector 1 (bits for sector 1 -> 0x10)
        authenticate(sector: 0)
        let mad1: [UInt8] = hexToBytes("140103E103E103E103E103E103E103E1")! // includes version and directory entries
        add(3, "Write MAD1 (S0 B1)", Commands.writeFullBlock(sector: 0, block: 1, dataBlock: mad1))
        
        // MAD2 block (sector 0, block 2)
        let mad2: [UInt8] = hexToBytes("03E103E103E103E103E103E103E103E1")!
        add(3, "Write MAD2 (S0 B2)", Commands.writeFullBlock(sector: 0, block: 2, dataBlock: mad2))
        
        // Sector 0 trailer: set MAD access and keep keys default (Key B left FF...)
        authenticate(sector: 0)
        let madTrailer: [UInt8] = [
            0xD3, 0xF7, 0xD3, 0xF7, 0xD3, 0xF7, // NFC Forum MAD Key A
            0x78, 0x77, 0x88,                   // Access bits for MAD
            0xC1,                               // GPB
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF  // Key B
        ]
        add(4, "Write MAD Trailer (S0 B3)", Commands.writeFullBlock(sector: 0, block: 3, dataBlock: madTrailer))
        
        // Now write NDEF TLV starting at Sector 1, Block 0
        var bytes = ndef
        var sector: UInt8 = 1
        var blockInSector: UInt8 = 0
        
        authenticate(sector: sector)
        
        while !bytes.isEmpty {
            // Skip trailer block in any sector
            let blocksPerSector: UInt8 = (sector < 32) ? 4 : 16
            if blockInSector == blocksPerSector - 1 {
                sector &+= 1
                blockInSector = 0
                authenticate(sector: sector)
                continue
            }
            
            // Prepare 16-byte block
            let count = min(16, bytes.count)
            var block = Array(bytes.prefix(count))
            if block.count < 16 { block.append(contentsOf: Array(repeating: 0x00, count: 16 - block.count)) }
            bytes.removeFirst(count)
            
            add(5, "Write S\(sector) B\(blockInSector)", Commands.writeFullBlock(sector: sector, block: blockInSector, dataBlock: block))
            
            blockInSector &+= 1
        }
        
        // Halt and beep
        add(6, "MiFare HltA", Commands.cmdHltA())
        nfcManager.sendCommand(Commands.beep(msec: 80))
    }
    
    func sendCommonULCommands() {
        add(1,"MiFare request",Commands.mifareRequest())
        add(2,"MiFare anticolision",Commands.mifareAnticolision())
        add(3,"MiFare UL select",Commands.mifareULSelect())
    }
    
    func getBalance() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.GET_BALANCE_MESSAGE
        nfcManager.currentKey = currentKey
        nfcManager.isCurrentKeyA = currentKeyType == "KeyA"
        nfcManager.currentSector = currentSector
        nfcManager.currentBlock = UInt8(currentBlock)!
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "MiFare request", cmd: Commands.mifareRequest()))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func setBalance() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SET_BALANCE_MESSAGE
        nfcManager.currentKey = currentKey
        nfcManager.isCurrentKeyA = currentKeyType == "KeyA"
        nfcManager.currentSector = currentSector
        nfcManager.currentBlock = UInt8(currentBlock)!
        nfcManager.balance = balance
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "MiFare request", cmd: Commands.mifareRequest()))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func incBalance() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.INC_BALANCE_MESSAGE
        nfcManager.currentKey = currentKey
        nfcManager.isCurrentKeyA = currentKeyType == "KeyA"
        nfcManager.currentSector = currentSector
        nfcManager.currentBlock = UInt8(currentBlock)!
        nfcManager.modification = modification
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "MiFare request", cmd: Commands.mifareRequest()))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func decBalance() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.DEC_BALANCE_MESSAGE
        nfcManager.currentKey = currentKey
        nfcManager.isCurrentKeyA = currentKeyType == "KeyA"
        nfcManager.currentSector = currentSector
        nfcManager.currentBlock = UInt8(currentBlock)!
        nfcManager.modification = modification
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "MiFare request", cmd: Commands.mifareRequest()))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }

    func saveNewPassKey() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.SETKEY_MESSAGE
        nfcManager.currentKey = currentKeyForChange
        nfcManager.newKey = newKeyForChange
        nfcManager.accessBits = keyAccessBitsForChange
        nfcManager.isCurrentKeyA = keyTypeForChange == "KeyA"
        nfcManager.isNewKeyA = newKeyTypeForChange == "KeyA"
        nfcManager.currentSector = currentSectorForChange
        nfcManager.currentBlock = 3
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "MiFare request", cmd: Commands.mifareRequest()))
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare anticolision", cmd: Commands.mifareAnticolision()))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }
    
    func getAccessBits() {
        if nfcManager.serialPort == nil || nfcManager.serialPort?.isOpen == false {
            return
        }
        nfcManager.clearLog()
        nfcManager.commandsProcessor = SerialManager.PROCESS.GET_ACCESSBITS_MESSAGE
        nfcManager.currentKey = currentKeyForChange
        nfcManager.isCurrentKeyA = keyTypeForChange == "KeyA"
        nfcManager.currentSector = currentSectorForChange
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:1, description: "MiFare request", cmd: Commands.mifareRequest()))
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:2, description: "MiFare anticolision", cmd: Commands.mifareAnticolision()))
        nfcManager.addCommand(cmd: ER302Driver.CommandStruct(id:3, description: "MiFare read block (\(currentSectorForChange) / 3)", cmd: Commands.readBlock(sector: currentSectorForChange, block: 3)))
        nfcManager.sendCommand(Commands.beep(msec: 50))
    }

    func parseCSV(at url: URL) -> [Person] {
        var people: [Person] = []
        
        // Sandbox engedély kérése
        guard url.startAccessingSecurityScopedResource() else { return [] }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Az első sort (fejlécet) általában kihagyjuk: .dropFirst()
            for row in rows.dropFirst() {
                let columns = row.components(separatedBy: ",")
                if columns.count >= 3 {
                    let person = Person(
                        name: columns[0].trimmingCharacters(in: .whitespaces),
                        email: columns[1].trimmingCharacters(in: .whitespaces),
                        phone: columns[2].trimmingCharacters(in: .whitespaces)
                    )
                    people.append(person)
                }
            }
        } catch {
            print("Hiba a fájl beolvasásakor: \(error)")
        }
        
        return people
    }
}

#Preview {
    ContentView()
}

