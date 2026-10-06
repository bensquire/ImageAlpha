// Posts mouse and scroll events, which System Events can't. Compiled on first
// use by driver.sh. Coordinates are global, origin at the main display's top
// left, the same as System Events' `position`. A point may come as one "x y"
// argument, as driver.sh's `canvas` and `finder` print it.
//   input move <x> <y>
//   input drag <x1> <y1> <x2> <y2>
//   input scroll <x> <y> <dx> <dy> [command|option]
import CoreGraphics
import Foundation

func post(_ type: CGEventType, at point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
}

func pause(_ milliseconds: UInt32) { usleep(milliseconds * 1000) }

let args = CommandLine.arguments.dropFirst().flatMap { $0.split(separator: " ").map(String.init) }
let numbers = args.dropFirst().compactMap { Double($0) }

switch (args.first, numbers.count) {
case ("move", 2):
    post(.mouseMoved, at: CGPoint(x: numbers[0], y: numbers[1]))
case ("drag", 4):
    let start = CGPoint(x: numbers[0], y: numbers[1])
    let end = CGPoint(x: numbers[2], y: numbers[3])
    post(.mouseMoved, at: start)
    pause(150)
    post(.leftMouseDown, at: start)
    pause(150)
    // In steps, so the source sees a drag begin and the target sees it arrive.
    let steps = 40
    for step in 1...steps {
        let fraction = Double(step) / Double(steps)
        post(.leftMouseDragged, at: CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction))
        pause(15)
    }
    pause(300)
    post(.leftMouseUp, at: end)
case ("scroll", 4):
    post(.mouseMoved, at: CGPoint(x: numbers[0], y: numbers[1]))
    pause(100)
    let event = CGEvent(
        scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
        wheel1: Int32(numbers[3]), wheel2: Int32(numbers[2]), wheel3: 0
    )
    switch args.last {
    case "command": event?.flags = .maskCommand
    case "option": event?.flags = .maskAlternate
    default: break
    }
    event?.post(tap: .cghidEventTap)
default:
    FileHandle.standardError.write(Data("usage: input move x y | drag x1 y1 x2 y2 | scroll x y dx dy [command|option]\n".utf8))
    exit(1)
}
