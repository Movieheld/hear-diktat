import AVFoundation
import Foundation

// micrec <output.wav> [maxSeconds]
// Nimmt vom Standard-Mikrofon auf: 16 kHz, mono, 16-bit PCM (genau das, was whisper.cpp will).
// Stoppt bei ENTER, bei Ctrl-C oder nach maxSeconds.

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: micrec <output.wav> [maxSeconds]\n".data(using: .utf8)!)
    exit(2)
}
let outURL = URL(fileURLWithPath: args[1])
let maxSeconds = args.count >= 3 ? (Double(args[2]) ?? 300) : 300

// Mikrofon-Berechtigung anfragen (der Prompt erscheint fuer die aufrufende App, z.B. Terminal)
let sem = DispatchSemaphore(value: 0)
var granted = false
AVCaptureDevice.requestAccess(for: .audio) { ok in
    granted = ok
    sem.signal()
}
sem.wait()
guard granted else {
    FileHandle.standardError.write("Kein Mikrofon-Zugriff. Systemeinstellungen > Datenschutz & Sicherheit > Mikrofon.\n".data(using: .utf8)!)
    exit(1)
}

let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000.0,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false,
]

let recorder: AVAudioRecorder
do {
    recorder = try AVAudioRecorder(url: outURL, settings: settings)
} catch {
    FileHandle.standardError.write("Recorder-Fehler: \(error)\n".data(using: .utf8)!)
    exit(1)
}

func finish() -> Never {
    if recorder.isRecording { recorder.stop() }
    FileHandle.standardError.write("\n".data(using: .utf8)!)
    exit(0)
}

// Ctrl-C sauber behandeln
signal(SIGINT, SIG_IGN)
let sigsrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
sigsrc.setEventHandler { finish() }
sigsrc.resume()

guard recorder.record(forDuration: maxSeconds) else {
    FileHandle.standardError.write("Aufnahme konnte nicht gestartet werden.\n".data(using: .utf8)!)
    exit(1)
}

FileHandle.standardError.write("● Aufnahme läuft — ENTER zum Stoppen.\n".data(using: .utf8)!)
_ = readLine()
finish()
