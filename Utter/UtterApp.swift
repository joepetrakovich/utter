//
//  UtterApp.swift
//  Utter
//
//  Created by Joe Petrakovich on 2026/04/25.
//

import AppKit
import SwiftData
import SwiftUI


@main
struct UtterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transcription.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    let transcriptionViewModel: TranscriptionViewModel
    
    init() {
        transcriptionViewModel = .init(modelContext: sharedModelContainer.mainContext)
        appDelegate.transcriptionViewModel = transcriptionViewModel
    }

    var body: some Scene {
        MenuBarExtra {
            MainMenu()
                .environment(transcriptionViewModel)
                .modelContainer(sharedModelContainer)
        } label: {
            Label("Utter", systemImage: "waveform")
        }
       .menuBarExtraStyle(.window)
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    var eventTap: CFMachPort?
    var transcriptionViewModel: TranscriptionViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let pointerToSelf = Unmanaged.passUnretained(self).toOpaque()

        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)
        
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: handleTappedEvent,
            userInfo: pointerToSelf
        ) {
            self.eventTap = tap
            let runLoopSource = CFMachPortCreateRunLoopSource(
                kCFAllocatorDefault,
                tap,
                0
            )
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            print("Failed to create event tap.")
        }
    }
}

func handleTappedEvent(
    proxy: CGEventTapProxy,
    type: CGEventType,
    cgEvent: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    
    guard let nsEvent = NSEvent(cgEvent: cgEvent), let userInfo = userInfo else {
        return Unmanaged.passUnretained(cgEvent)
    }
   
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    guard let vm = appDelegate.transcriptionViewModel else {
        return Unmanaged.passUnretained(cgEvent)
    }

    if vm.uiState.isRegisteringHotKey {
        if nsEvent.type == .keyDown,
        let modifier = modifierAndSideByModifierKeyCode.first(where: { nsEvent.modifierFlags.contains($0.value.mask) }) {
            vm.handleEvent(
                .hotkeyRegistrationEventFired(event: .keyPlusModifierDown(key: nsEvent.keyCode, modifier: modifier.value))
            )
        }
      
        if nsEvent.type == .flagsChanged, let key = modifierAndSideByModifierKeyCode[nsEvent.keyCode] {
            let isKeyDown = nsEvent.modifierFlags.contains(key.mask)
            vm.handleEvent(
                .hotkeyRegistrationEventFired(event: isKeyDown ? .modifierDown(key) : .modifierUp(key))
            )
        }

       return nil
    }
   
    guard let hotKey = vm.hotKey else {
        return Unmanaged.passUnretained(cgEvent)
    }
    
    //mod only
    if hotKey.key == nil,
       nsEvent.type == .flagsChanged,
       let modifierAndSide = modifierAndSideByModifierKeyCode[nsEvent.keyCode],
       modifierAndSide == hotKey.modifier
    {
        let isKeyDown = nsEvent.modifierFlags.contains(hotKey.modifier.mask)
        vm.handleEvent(isKeyDown ? .hotkeyPressed : .hotkeyReleased)
        return nil
    }
    
    //mod + key
    if [.keyDown, .keyUp].contains(nsEvent.type), nsEvent.modifierFlags.contains(hotKey.modifier.mask), hotKey.key == nsEvent.keyCode {
        vm.handleEvent(nsEvent.type == .keyDown ? .hotkeyPressed : .hotkeyReleased)
        return nil
    }

    return Unmanaged.passUnretained(cgEvent)
}

enum Side: String {
    case left
    case right
}
struct ModifierKey: Equatable {
    let mask: NSEvent.ModifierFlags
    let side: Side
}
let modifierAndSideByModifierKeyCode: [UInt16: ModifierKey] = [
    0x38: .init(mask: .shift, side: .left),
    0x3C: .init(mask: .shift, side: .right),
    0x3B: .init(mask: .control, side: .left),
    0x3E: .init(mask: .control, side: .right),
    0x3A: .init(mask: .option, side: .left),
    0x3D: .init(mask: .option, side: .right),
    0x37: .init(mask: .command, side: .left),
    0x36: .init(mask: .command, side: .right)
]
