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
    var isRecording: Bool = false
    var transcriptions: [Transcription] = []
}

@Observable class TranscriptionViewModel {
    private let recorder: AudioRecorder = .init()
    private let asrManager = AsrManager(config: .default)
    private let modelContext: ModelContext
    private var hotKeyRegistrationState: HotKeyRegistrationStateMachine = .init()

    var uiState: TranscriptionUiState = .init()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        Task {
            let models = try await AsrModels.downloadAndLoad(version: .v2)  //TODO: offline
            try await asrManager.loadModels(models)
            
            refreshHistory()
        }
        
        //TODO: set hotkeyregstate based on userdefaults
    }
    
    var hotKey: (modifier: ModifierKey, key: UInt16?)? {
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
            startRecording()
        case .hotkeyReleased:
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
                
                uiState.hotKey = "\(modifier.side.rawValue) \(modifier.mask.rawValue) + \(key, default: "none")"
            }
        case .registerHotkeyFocusOut:
            uiState.isRegisteringHotKey = false
        }
    }
    
    private func startRecording() {
        print("pressed")
        if recorder.isRunning {
            print("recorder was still running")
            return
        }
        //might need guards to throw away rapid clicks
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("authorized")
            recorder.start()

        case .notDetermined:
            print("notDetermined")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("granted")
                    self.recorder.start()
                }
            }

        case .denied:
            print("denied")
        case .restricted:
            print("restricted")
        @unknown default:
            print("unknown")
        }
    }
    
    private func stopRecording() {
        print("released")
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
}


enum HotKeyRegistrationState: Equatable {
    case idle
    case awaitingResult(ModifierKey)
    case registered(ModifierKey, key: UInt16? = nil)
}

enum HotkeyRegistrationEvent {
    case modifierDown(ModifierKey)
    case keyPlusModifierDown(key: UInt16, modifier: ModifierKey)
    case modifierUp(ModifierKey)
}

class HotKeyRegistrationStateMachine {
    var currentState: HotKeyRegistrationState = .idle

    func handle(event: HotkeyRegistrationEvent) {
        switch (currentState, event) {
            
        case (.idle, .modifierDown(let modifier)):
            currentState = .awaitingResult(modifier)
            
        case (.awaitingResult, .keyPlusModifierDown(let keyCode, let modifier)):
            currentState = .registered(modifier, key: keyCode)
            
        case (.awaitingResult, .modifierUp(let modifier)):
            currentState = .registered(modifier, key: nil)
            
        default:
            break
        }
    }
}
