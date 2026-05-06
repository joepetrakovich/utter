//
//  Menu.swift
//  Utter
//
//  Created by Joe Petrakovich on 2026/04/25.
//

import SwiftData
import SwiftUI

struct MainMenu: View {
    @Environment(TranscriptionViewModel.self) private var transcriptionViewModel

    var body: some View {
        MainMenuContent(
            uiState: transcriptionViewModel.uiState,
            onEvent: transcriptionViewModel.handleEvent
        )
    }
}

struct MainMenuContent: View {
    let uiState: TranscriptionUiState
    let onEvent: (TranscriptionEvent) -> Void
    
    @State private var showHistory = true
    @State private var recentlyClicked: Transcription?
    @FocusState private var isHotkeyFocused: Bool
    
    init(
        uiState: TranscriptionUiState,
        onEvent: @escaping (TranscriptionEvent) -> Void
    ) {
        self.uiState = uiState
        self.onEvent = onEvent
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            if !uiState.transcriptions.isEmpty {
                Text("Recent Transcriptions")
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .font(.headline)
                    .opacity(0.6)
                
                ForEach(uiState.transcriptions, id: \.self) { t in
                    Button {
                        onEvent(.historyEntryClicked(entry: t))
                        recentlyClicked = t
                        Task {
                            try await Task.sleep(for: .seconds(1))
                            recentlyClicked = nil
                        }
                    } label: {
                        HStack {
                            Text(t.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if recentlyClicked === t {
                                Image(systemName: "checkmark")
                                    .opacity(0.6)
                            } else {
                                Image(systemName: "document.on.document")
                                    .opacity(0.6)
                            }
                        }.frame(minHeight: 18)
                            .help(t.text)
                    }
                
                }
                
                Button {
                    onEvent(.historyClearClicked)
                } label: {
                    Text("Clear Recents")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider().padding(.horizontal, 8)
            }
            
            HStack {
                Text("Hotkey")
                Spacer()
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .opacity(uiState.isHotKeyPressed ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: uiState.isHotKeyPressed)
                TextField(uiState.hotKey ?? "None",
                          text: .constant(""),
                          onEditingChanged: { onEvent($0 ? .registerHotkeyFocused : .registerHotkeyFocusOut)}
                )
                .multilineTextAlignment(TextAlignment.center)
                .focused($isHotkeyFocused)
                .frame(maxWidth: 80)
                
            }
            .padding(.horizontal, 8)
            
            Divider().padding(.horizontal, 8)
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit Utter")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isHotkeyFocused = false
        }
        .onChange(of: uiState.isRegisteringHotKey) {
            if (!uiState.isRegisteringHotKey) {
                isHotkeyFocused = false
            }
        }
        .padding(6)
        .frame(maxWidth: 240, alignment: .leading)
        .buttonBorderShape(.capsule)
        .buttonStyle(MyButtonStyle())
    }
}

struct MyButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .lineLimit(1)
            .background(isHovered ? Color.gray.opacity(0.2) : Color.clear, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

#Preview {
    Menu("Utter") {
        MainMenuContent(
            uiState: .init(
                isRecording: false,
                transcriptions: [
                    .init(timestamp: Date(), text: "Hello, this is a sample transcription"),
                    .init(timestamp: Date(), text: "Something"),
                    .init(timestamp: Date(), text: "Another third example but this one is like if you were to ask a long question that spans a few sentences.")
                ]
            ),
            onEvent: { _ in }
        )
    }
    
    .frame(width: 100)
}


#Preview {
    MainMenuContent(
        uiState: .init(
            isRegisteringHotKey: true,
            isHotKeyPressed: true,
            isRecording: false,
            transcriptions: [
                .init(timestamp: Date(), text: "Hello, this is a sample transcription"),
                .init(timestamp: Date(), text: "Something"),
                .init(timestamp: Date(), text: "Another third example but this one is like if you were to ask a long question that spans a few sentences.")
        ]),
        onEvent: { _ in }
    ).frame(maxWidth: 240)
}
