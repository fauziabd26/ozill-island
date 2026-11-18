import Foundation

/// Bridge eksekusi skrip macOS (AppleScript / JXA) asinkron dan terisolasi
/// dengan batas timeout ketat (1.5s) agar tidak pernah memblokir UI atau MainActor.
public enum ScriptBridge {
    public static func executeAppleScript(_ script: String, timeout: TimeInterval = 1.5) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                var hasResumed = false
                let lock = NSLock()
                
                func resumeOnce(success: Bool, output: String) {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: (success, output))
                    }
                }
                
                // Watchdog timer untuk timeout
                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler {
                    if process.isRunning {
                        let pid = process.processIdentifier
                        process.terminate()
                        // Kirim SIGKILL jika proses masih berjalan agar tidak ada orphan/zombie process tertinggal
                        if pid > 0 {
                            kill(pid, SIGKILL)
                        }
                    }
                    try? outputPipe.fileHandleForReading.close()
                    try? errorPipe.fileHandleForReading.close()
                    resumeOnce(success: false, output: "Execution timed out (\(timeout)s)")
                }
                timer.resume()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    timer.cancel()
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    try? outputPipe.fileHandleForReading.close()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    if process.terminationStatus == 0 {
                        try? errorPipe.fileHandleForReading.close()
                        resumeOnce(success: true, output: output)
                    } else {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        try? errorPipe.fileHandleForReading.close()
                        let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        resumeOnce(success: false, output: errStr.isEmpty ? output : errStr)
                    }
                } catch {
                    timer.cancel()
                    try? outputPipe.fileHandleForReading.close()
                    try? errorPipe.fileHandleForReading.close()
                    resumeOnce(success: false, output: error.localizedDescription)
                }
            }
        }
    }
}
