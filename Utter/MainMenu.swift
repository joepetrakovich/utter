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
            
            if uiState.isDownloadingAndLoadingModels {
                HStack {
                    Text("Loading models...")
                        .opacity(0.6)
                        .padding(.leading, 8)
                        .frame(minHeight: 28)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            
            if !uiState.transcriptions.isEmpty {
                HistoryMenu(
                    transcriptions: uiState.transcriptions,
                    onTranscriptionClicked: { onEvent(.historyEntryClicked(entry: $0)) },
                    onClearHistoryClicked: { onEvent(.historyClearClicked) }
                )
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
        .frame(maxWidth: 200, alignment: .leading)
        .buttonBorderShape(.capsule)
        .buttonStyle(MenuLikeButtonStyle())
    }
}

struct TruncatedText: View {
    let text: String
    let numChars: Int
    
    var body: some View {
        Text(truncatedText)
    }
    
    private var truncatedText: String {
        guard text.count > numChars else {
            return text
        }
        
        let ellipsis = "..."
        let availableChars = numChars - ellipsis.count
        
        guard availableChars > 0 else {
            return ellipsis
        }
        
        let prefix = String(text.prefix(availableChars))
        
        if let lastSpace = prefix.lastIndex(of: " ") {
            let truncated = String(prefix.prefix(upTo: lastSpace))
            return truncated + ellipsis
        }
        
        return prefix + ellipsis
    }
}

struct HistoryMenu: View {
    var transcriptions: [Transcription]
    let onTranscriptionClicked: (Transcription) -> Void
    let onClearHistoryClicked: () -> Void
    
    var body: some View {
        
        Menu {
            ForEach(transcriptions, id: \.self) { t in
                Button {
                    onTranscriptionClicked(t)
                } label: {
                    TruncatedText(text: t.text, numChars: 50)
                    Image(systemName: "document.on.document")
                        .opacity(0.6)
                }
                .help(t.text)
            }
            
            Button {
                onClearHistoryClicked()
            } label: {
                Text("Clear History")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }label: {
            HStack {
                Text("History")
                Spacer()
                Image(systemName: "chevron.right")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 10, height: 10)
                    .fontWeight(.bold)
            }
        }
    }
}

struct MenuLikeButtonStyle: ButtonStyle {
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
    MainMenuContent(
        uiState: .init(
            isRegisteringHotKey: true,
            isHotKeyPressed: true,
            transcriptions: [
                .init(timestamp: Date(), text: "Hello, this is a sample transcription"),
                .init(timestamp: Date(), text: "Something"),
                .init(timestamp: Date(), text: "Another third example but this one is like if you were to ask a long question that spans a few sentences.")
        ],
        isDownloadingAndLoadingModels: true,
            ),
        onEvent: { _ in }
    ).frame(maxWidth: 200)
}
