//
//  UtterApp.swift
//  Utter
//
//  Created by Joe Petrakovich on 2026/04/25.
//

import SwiftUI
import SwiftData
import AppKit


func handleKeyDown(
    proxy: CGEventTapProxy,
    type: CGEventType,
    cgEvent: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    
    if let nsEvent = NSEvent(cgEvent: cgEvent),
       nsEvent.type == .keyDown {
        // check if CMD pressed
        //let cmdPressed = nsEvent.modifierFlags.contains(.command)
        // get current key press
        let pressedChar = nsEvent.charactersIgnoringModifiers?.lowercased() ?? ""
        // was CMD + H pressed?
        if pressedChar == "h" {
            print("H pressed")
            return nil // swallow event
        }
    }
    // Let all other keystrokes pass
    return Unmanaged.passUnretained(cgEvent)
}

@main
struct UtterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        MenuBarExtra {
            //ContentView()
            Button("Action 1") { /* Logic */ }
            Button("Action 2") { /* Logic */ }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            Label("Utter", systemImage: "waveform")
        }
        .modelContainer(sharedModelContainer)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var eventTap: CFMachPort?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initial setup code here
        print("here")
        // define a keydown event
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: handleKeyDown,
            userInfo: nil
        ) {
            self.eventTap = tap
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            print("Failed to create event tap.")
        }
    }
}
