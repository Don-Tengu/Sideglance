import AVFoundation
import Foundation

struct CameraDevice: Equatable {
    let id: String
    let name: String
}

enum CameraState: Equatable {
    case inactive, permission, denied, restricted, starting, live, unavailable, interrupted, failed
}

final class Camera {
    struct Snapshot {
        var state: CameraState = .inactive
        var devices: [CameraDevice] = []
        var activeID: String?
    }

    private let session: AVCaptureSession
    let previewLayer: AVCaptureVideoPreviewLayer
    var onChange: ((Snapshot) -> Void)? // Set and called on the main queue.

    private let queue = DispatchQueue(label: "com.bartolomeoquaranto.viewfinder.capture", qos: .userInitiated)
    private lazy var discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
        mediaType: .video,
        position: .unspecified
    )
    // Session configuration and the following mutable state belong to the capture queue.
    private var snapshot = Snapshot()
    private var desired = false
    private var interrupted = false
    private var preferredID: String?
    private var mirrored = true
    private var input: AVCaptureDeviceInput?
    private var observers: [NSObjectProtocol] = []

    init() {
        session = AVCaptureSession()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                guard let device = note.object as? AVCaptureDevice, device.hasMediaType(.video), let self else { return }
                self.queue.async { self.update() }
            })
        }
        for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification,
                     AVCaptureSession.interruptionEndedNotification] {
            observers.append(center.addObserver(forName: name, object: session, queue: nil) { [weak self] note in
                let name = note.name
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
                guard let self else { return }
                self.queue.async { self.handleSessionEvent(name, error: error) }
            })
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func setPreviewVisible(_ visible: Bool) {
        queue.async {
            self.desired = visible
            self.update()
        }
    }

    func select(_ id: String?) {
        queue.async {
            self.preferredID = id
            self.update()
        }
    }

    func retry() {
        queue.async { self.update() }
    }

    func setMirrored(_ mirrored: Bool) {
        queue.async {
            self.mirrored = mirrored
            self.updateMirroring()
        }
    }

    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in self?.retry() }
    }

    private func publish(_ state: CameraState) {
        snapshot.state = state
        snapshot.activeID = input?.device.uniqueID
        let result = snapshot
        DispatchQueue.main.async { [weak self] in self?.onChange?(result) }
    }

    private func stop() {
        if session.isRunning { session.stopRunning() }
        interrupted = false
    }

    private func update() {
        guard desired else {
            stop()
            publish(.inactive)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined: publish(.permission); return
        case .denied: stop(); publish(.denied); return
        case .restricted: stop(); publish(.restricted); return
        @unknown default: stop(); publish(.restricted); return
        }

        let devices = discovery.devices.filter(\.isConnected)
        snapshot.devices = devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
        let defaultID = AVCaptureDevice.default(for: .video)?.uniqueID
        let camera = devices.first { $0.uniqueID == preferredID }
            ?? devices.first { $0.uniqueID == defaultID }
            ?? devices.first
        guard let camera else {
            stop()
            if let input {
                session.beginConfiguration()
                session.removeInput(input)
                session.commitConfiguration()
                self.input = nil
            }
            publish(.unavailable)
            return
        }

        if input?.device.uniqueID != camera.uniqueID || input?.device.isConnected != true {
            publish(.starting)
            guard configure(camera) else {
                publish(.failed)
                return
            }
        }

        updateMirroring()
        if !session.isRunning && !interrupted {
            publish(.starting)
            session.startRunning()
        }
        if interrupted {
            publish(.interrupted)
        } else {
            publish(session.isRunning ? .live : .failed)
        }
    }

    private func updateMirroring() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }

    private func configure(_ device: AVCaptureDevice) -> Bool {
        guard let next = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let previous = input
        if let previous { session.removeInput(previous) }
        guard session.canAddInput(next) else {
            input = nil
            if let previous, previous.device.isConnected, session.canAddInput(previous) {
                session.addInput(previous)
                input = previous
            }
            return false
        }

        session.addInput(next)
        if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
        input = next
        return true
    }

    private func handleSessionEvent(_ name: Notification.Name, error: AVError?) {
        guard desired else { return }
        switch name {
        case AVCaptureSession.wasInterruptedNotification:
            interrupted = true
            publish(.interrupted)
        case AVCaptureSession.interruptionEndedNotification:
            interrupted = false
            update()
        case AVCaptureSession.runtimeErrorNotification:
            if error?.code == .deviceWasDisconnected || input?.device.isConnected == false {
                update()
            } else if !interrupted {
                publish(.failed)
            }
        default: break
        }
    }
}
