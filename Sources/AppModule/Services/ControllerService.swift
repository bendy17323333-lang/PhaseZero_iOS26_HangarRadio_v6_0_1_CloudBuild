import Foundation
import GameController
import UIKit

@MainActor
protocol ControllerServiceDelegate: AnyObject {
    func controllerConnectionChanged(name: String?)
    func controllerAxesChanged(_ payload: [String: Any])
    func controllerPressed(_ action: ControllerAction)
}

enum ControllerAction {
    case primary
    case secondary
    case reroll
    case pause
    case previous
    case next
}

@MainActor
final class ControllerService: NSObject {
    weak var delegate: ControllerServiceDelegate?

    private var controller: GCController?
    private var displayLink: CADisplayLink?
    private var previousButtons = ButtonState()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(didConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        displayLink?.invalidate()
    }

    func start() {
        attach(GCController.controllers().first)
        // Swift Playgrounds can stall while actively scanning. Existing and newly connected paired controllers are detected without this call.
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        GCController.stopWirelessControllerDiscovery()
        displayLink?.invalidate()
        displayLink = nil
        attach(nil)
    }

    @objc private func didConnect(_ note: Notification) {
        attach(note.object as? GCController)
    }

    @objc private func didDisconnect(_ note: Notification) {
        guard let disconnected = note.object as? GCController, disconnected == controller else { return }
        attach(GCController.controllers().first(where: { $0 != disconnected }))
    }

    private func attach(_ newController: GCController?) {
        controller = newController
        previousButtons = ButtonState()
        delegate?.controllerConnectionChanged(name: newController?.vendorName ?? (newController == nil ? nil : "游戏手柄"))
        if newController == nil {
            delegate?.controllerAxesChanged(["connected": false])
        }
    }

    @objc private func tick() {
        guard let gamepad = controller?.extendedGamepad else { return }

        let move = radial(
            x: gamepad.leftThumbstick.xAxis.value,
            y: -gamepad.leftThumbstick.yAxis.value,
            deadzone: 0.14,
            exponent: 1.12
        )
        let aim = radial(
            x: gamepad.rightThumbstick.xAxis.value,
            y: -gamepad.rightThumbstick.yAxis.value,
            deadzone: 0.16,
            exponent: 1.24
        )
        let fire = gamepad.rightTrigger.value > 0.16 || gamepad.rightShoulder.isPressed

        delegate?.controllerAxesChanged([
            "connected": true,
            "mx": move.x,
            "my": move.y,
            "moveMag": move.magnitude,
            "ax": aim.x,
            "ay": aim.y,
            "aimMag": aim.magnitude,
            "fire": fire
        ])

        let buttons = ButtonState(
            primary: gamepad.buttonA.isPressed,
            secondary: gamepad.buttonB.isPressed,
            reroll: gamepad.buttonX.isPressed,
            pause: gamepad.buttonMenu.isPressed,
            previous: gamepad.dpad.left.isPressed || gamepad.leftShoulder.isPressed,
            next: gamepad.dpad.right.isPressed
        )

        emitEdge(buttons.primary, previousButtons.primary, .primary)
        emitEdge(buttons.secondary, previousButtons.secondary, .secondary)
        emitEdge(buttons.reroll, previousButtons.reroll, .reroll)
        emitEdge(buttons.pause, previousButtons.pause, .pause)
        emitEdge(buttons.previous, previousButtons.previous, .previous)
        emitEdge(buttons.next, previousButtons.next, .next)
        previousButtons = buttons
    }

    private func emitEdge(_ current: Bool, _ previous: Bool, _ action: ControllerAction) {
        if current && !previous { delegate?.controllerPressed(action) }
    }

    private func radial(x: Float, y: Float, deadzone: Float, exponent: Float) -> (x: Double, y: Double, magnitude: Double) {
        let raw = hypot(x, y)
        guard raw > deadzone else { return (0, 0, 0) }
        let normalized = min(max((raw - deadzone) / (1 - deadzone), 0), 1)
        let magnitude = pow(normalized, exponent)
        return (Double(x / raw * magnitude), Double(y / raw * magnitude), Double(magnitude))
    }

    private struct ButtonState {
        var primary = false
        var secondary = false
        var reroll = false
        var pause = false
        var previous = false
        var next = false
    }
}
