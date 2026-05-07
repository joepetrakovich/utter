//
//  TranscriptionViewModel.swift
//  Utter
//
//  Created by Joe Petrakovich on 2026/04/27.
//

import FluidAudio
import Foundation
import AVFoundation
import AppKit
import SwiftData

enum TranscriptionEvent {
    case hotkeyPressed
    case hotkeyReleased
    case historyEntryClicked(entry: Transcription)
    case historyClearClicked
    case registerHotkeyFocused
    case registerHotkeyFocusOut
    case hotkeyRegistrationEventFired(event: HotkeyRegistrationEvent)
}

struct TranscriptionUiState {
    var isRegisteringHotKey: Bool = false
    var hotKey: String? = nil
    var isHotKeyPressed: Bool = false
    var transcriptions: [Transcription] = []
    var isDownloadingAndLoadingModels: Bool = false
}

@Observable class TranscriptionViewModel {
    private let recorder: AudioRecorder = .init()
    private let asrManager = AsrManager(config: .default)
    private let modelContext: ModelContext
    private var hotKeyRegistrationState: HotKeyRegistrationStateMachine = .init()

    var uiState: TranscriptionUiState = .init()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        uiState.isDownloadingAndLoadingModels = true
        
        Task {
            let models = try await AsrModels.downloadAndLoad(version: .v2) 
            try await asrManager.loadModels(models)
            
            await MainActor.run {
                refreshHistory()
                uiState.isDownloadingAndLoadingModels = false
            }
        }
        
        loadHotKeyState()
    }
    
    
    var hotKey: (modifier: ModifierKey, key: NonModifierKey?)? {
        guard case .registered(let modifier, let key) = hotKeyRegistrationState.currentState else {
            return nil
        }
              
        return (modifier, key)
      }
    
    func refreshHistory() {
        var fetchDescriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        fetchDescriptor.fetchLimit = 3
        let transcriptions = (try? modelContext.fetch(fetchDescriptor)) ?? []
        uiState.transcriptions = Array(transcriptions)
    }
    
    func handleEvent(_ event: TranscriptionEvent) {
        switch event {
        case .hotkeyPressed:
            uiState.isHotKeyPressed = true
            startRecording()
        case .hotkeyReleased:
            uiState.isHotKeyPressed = false
            stopRecording()
        case .historyEntryClicked(entry: let entry):
            insertHistoryEntry(entry)
        case .historyClearClicked:
            clearHistory()
        case .registerHotkeyFocused:
            uiState.isRegisteringHotKey = true
            hotKeyRegistrationState = .init()
        case .hotkeyRegistrationEventFired(let event):
            hotKeyRegistrationState.handle(event: event)
            if case .registered(let modifier, let key) = hotKeyRegistrationState.currentState {
                uiState.isRegisteringHotKey = false
                print("hotkey set: \(hotKeyRegistrationState.currentState)")
                uiState.hotKey = "\(modifier.display(includeSide: key == nil))\(key?.character.uppercased() ?? "")"
                saveHotKey()
            }
        case .registerHotkeyFocusOut:
            uiState.isRegisteringHotKey = false
        }
    }
    
    private func startRecording() {
        if recorder.isRunning {
            print("recorder is still running")
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            recorder.start()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    self.recorder.start()
                }
            }

        case .denied:
            print("audio capture authorization was denied")
        case .restricted:
            print("audio capture authorization is restricted")
        @unknown default:
            print("audio capture authorization failed in an unkown state")
        }
    }
    
    private func stopRecording() {
        if recorder.isRunning, let audioBuffer = recorder.stopAndGetBuffer() {
            Task {
                var decoderState = try TdtDecoderState()
                let result = try await asrManager.transcribe(audioBuffer, decoderState: &decoderState)
                
                print("Transcription: \(result)")
                if (result.text.trimmingCharacters(in: .whitespacesAndNewlines)).isEmpty {
                    print("empty transcription, returning...")
                    return
                }
                
                copyToPasteboard(text: result.text)
                simulatePaste()
                let newTranscription = Transcription(timestamp: Date(), text: result.text)
                modelContext.insert(newTranscription)
                refreshHistory()
            }
        }
    }
    
    private func insertHistoryEntry(_ entry: Transcription) {
        copyToPasteboard(text: entry.text)
    }
    
    private func clearHistory() {
        let transcriptions = (try? modelContext.fetch(FetchDescriptor<Transcription>())) ?? []
        for transcription in transcriptions {
            modelContext.delete(transcription)
        }
        refreshHistory()
    }
    
    func copyToPasteboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
    }
    
    func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Key Down: Command + V
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        
        // Key Up: Command + V
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }

    private func saveHotKey() {
        guard let hotKey = hotKey else { return }
        let defaults = UserDefaults.standard
        defaults.set(hotKey.modifier.mask.rawValue, forKey: "hotKeyModifier")
        defaults.set(hotKey.modifier.side.rawValue, forKey: "hotKeyModifierSide")
        if let key = hotKey.key {
            defaults.set(key.keyCode, forKey: "hotKeyKeyCode")
            defaults.set(key.character, forKey: "hotKeyCharacter")
        } else {
            defaults.removeObject(forKey: "hotKeyKeyCode")
            defaults.removeObject(forKey: "hotKeyCharacter")
        }
    }

    private func loadHotKeyState() {
        guard let mask = UserDefaults.standard.object(forKey: "hotKeyModifier") as? UInt,
              let sideRaw = UserDefaults.standard.string(forKey: "hotKeyModifierSide") else {
            print("guard")
            return
        }
        let modifier = ModifierKey(
            mask: NSEvent.ModifierFlags(rawValue: mask),
            side: Side(rawValue: sideRaw) ?? .left
        )
        
        guard let keyCode = UserDefaults.standard.object(forKey: "hotKeyKeyCode") as? UInt16,
        let character = UserDefaults.standard.string(forKey: "hotKeyCharacter")
        else {
            hotKeyRegistrationState.currentState = .registered(modifier, nil)
            uiState.hotKey = modifier.display(includeSide: true)
            print("guard2")
            return
        }
        print("here")

        hotKeyRegistrationState.currentState = .registered(modifier, NonModifierKey(keyCode: keyCode, character: character))
        uiState.hotKey = modifier.display() + character.uppercased()
    }
}


enum HotKeyRegistrationState: Equatable {
    case idle
    case awaitingResult(ModifierKey)
    case registered(ModifierKey, NonModifierKey? = nil)
}

enum HotkeyRegistrationEvent {
    case modifierDown(ModifierKey)
    case keyPlusModifierDown(key: NonModifierKey, modifier: ModifierKey)
    case modifierUp(ModifierKey)
}

//Down on a modifier starts the awaiting state.
//From there, either a mod+key will set it OR a single modifier UP, whichever comes first.
//This only allows either a single modifier or a modifier plus a character to be used.
class HotKeyRegistrationStateMachine {
    var currentState: HotKeyRegistrationState = .idle

    func handle(event: HotkeyRegistrationEvent) {
        switch (currentState, event) {
            
        case (.idle, .modifierDown(let modifier)):
            currentState = .awaitingResult(modifier)
            
        case (.awaitingResult, .keyPlusModifierDown(let key, let modifier)):
            currentState = .registered(modifier, key)
            
        case (.awaitingResult, .modifierUp(let modifier)):
            currentState = .registered(modifier, nil)
            
        default:
            break
        }
    }
}
