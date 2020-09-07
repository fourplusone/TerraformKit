import Foundation

#if canImport(Darwin) && os(macOS)
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016, 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

// macOS's Foundation does not forward stdin to subprocesses when used from the
// terminal. Therefore a slightly modified version from swift-corelibs-foundation
// is used to spawn a process on macOS

import CoreFoundation

private func emptyRunLoopCallback(_ context : UnsafeMutableRawPointer?) -> Void {}

extension NSObject {
    func withUnretainedReference<T, R>(_ work: (UnsafePointer<T>) -> R) -> R {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque().assumingMemoryBound(to: T.self)
        return work(selfPtr)
    }
    
    func withUnretainedReference<T, R>(_ work: (UnsafeMutablePointer<T>) -> R) -> R {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque().assumingMemoryBound(to: T.self)
        return work(selfPtr)
    }
}

// Equal method for process in run loop source
private func processIsEqual(_ a : UnsafeRawPointer?, _ b : UnsafeRawPointer?) -> DarwinBoolean {
    
    let unmanagedProcessA = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let processA = unmanagedProcessA.takeUnretainedValue() as? Process else {
        return false
    }
    
    let unmanagedProcessB = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let processB = unmanagedProcessB.takeUnretainedValue() as? Process else {
        return false
    }
    
    guard processA == processB else {
        return false
    }
    
    return true
}

private func runloopIsEqual(_ a : UnsafeRawPointer?, _ b : UnsafeRawPointer?) -> DarwinBoolean {
    
    let unmanagedrunLoopA = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let runLoopA = unmanagedrunLoopA.takeUnretainedValue() as? RunLoop else {
        return false
    }
    
    let unmanagedRunLoopB = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let runLoopB = unmanagedRunLoopB.takeUnretainedValue() as? RunLoop else {
        return false
    }
    
    guard runLoopA == runLoopB else {
        return false
    }
    
    return true
}


// Retain method for run loop source
private func runLoopSourceRetain(_ pointer : UnsafeRawPointer?) -> UnsafeRawPointer? {
    let ref = Unmanaged<AnyObject>.fromOpaque(pointer!).takeUnretainedValue()
    let retained = Unmanaged<AnyObject>.passRetained(ref)
    return unsafeBitCast(retained, to: UnsafeRawPointer.self)
}

// Release method for run loop source
private func runLoopSourceRelease(_ pointer : UnsafeRawPointer?) -> Void {
    Unmanaged<AnyObject>.fromOpaque(pointer!).release()
}

extension NSObject {
    static func unretainedReference<R: NSObject>(_ value: UnsafeRawPointer) -> R {
        return unsafeBitCast(value, to: R.self)
    }
    
    static func unretainedReference<R: NSObject>(_ value: UnsafeMutableRawPointer) -> R {
        return unretainedReference(UnsafeRawPointer(value))
    }
    
}


private func WIFEXITED(_ status: Int32) -> Bool {
    return _WSTATUS(status) == 0
}

private func _WSTATUS(_ status: Int32) -> Int32 {
    return status & 0x7f
}

private func WIFSIGNALED(_ status: Int32) -> Bool {
    return (_WSTATUS(status) != 0) && (_WSTATUS(status) != 0x7f)
}

private func WEXITSTATUS(_ status: Int32) -> Int32 {
    return (status >> 8) & 0xff
}

private func WTERMSIG(_ status: Int32) -> Int32 {
    return status & 0x7f
}

private var managerThreadRunLoop : RunLoop? = nil
private var managerThreadRunLoopIsRunning = false
private var managerThreadRunLoopIsRunningCondition = NSCondition()

class WrappedProcess {
    
    let p: Process
    var isRunning: Bool = false
    var processIdentifier: pid_t = pid_t()
    private var processLaunchedCondition = NSCondition()
    private var _terminationStatus: Int32 = 0
    private var _terminationReason: Process.TerminationReason = .exit
    

    
    private var runLoopSourceContext : CFRunLoopSourceContext?
    private var runLoopSource : CFRunLoopSource?
    
    fileprivate weak var runLoop : RunLoop? = nil
    
    init(p: Process) {
        self.p = p
    }
    
    
    private static  var setup : () = {
        let thread = Thread {
            managerThreadRunLoop = RunLoop.current
            var emptySourceContext = CFRunLoopSourceContext()
            emptySourceContext.version = 0
            emptySourceContext.retain = runLoopSourceRetain
            emptySourceContext.release = runLoopSourceRelease
            emptySourceContext.equal = runloopIsEqual
            emptySourceContext.perform = emptyRunLoopCallback
            
            
            managerThreadRunLoop!.withUnretainedReference {
                (refPtr: UnsafeMutablePointer<UInt8>) in
                emptySourceContext.info = UnsafeMutableRawPointer(refPtr)
            }
            
            CFRunLoopAddSource(managerThreadRunLoop?.getCFRunLoop(), CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &emptySourceContext), .defaultMode)
            
            managerThreadRunLoopIsRunningCondition.lock()
            
            managerThreadRunLoop?.perform {
                managerThreadRunLoopIsRunning = true
                managerThreadRunLoopIsRunningCondition.broadcast()
                managerThreadRunLoopIsRunningCondition.unlock()
            }
            
            managerThreadRunLoop?.run()
            fatalError("Process manager run loop exited unexpectedly; it should run forever once initialized")
        }
        thread.start()
        managerThreadRunLoopIsRunningCondition.lock()
        while managerThreadRunLoopIsRunning == false {
            managerThreadRunLoopIsRunningCondition.wait()
        }
        managerThreadRunLoopIsRunningCondition.unlock()
    }()
    
    func run() throws {
        
        struct _NSErrorWithErrno : Error {
            var reading: Bool
            var path: String?
            var url: URL?
            var errno: Int32
            
            init(_ errno: Int32, reading: Bool, path: String) {
                self.errno = errno
                self.reading = reading
                self.path = path
            }
            
            init(_ errno: Int32, reading: Bool, url: URL?) {
                self.errno = errno
                self.reading = reading
                self.url = url
            }
        }
        
        _ = WrappedProcess.setup
        
        // Ensure that the launch path is set
        guard let launchPath = self.p.executableURL?.path else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        }
        
        func _throwIfPosixError(_ posixErrno: Int32) throws {
            if posixErrno != 0 {
                // When this is called, self.executableURL is already known to be non-nil
                let userInfo: [String: Any] = [ NSURLErrorKey: self.p.executableURL! ]
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno), userInfo: userInfo)
            }
        }
        
        self.processLaunchedCondition.lock()
        defer {
            self.processLaunchedCondition.broadcast()
            self.processLaunchedCondition.unlock()
        }
        
        // Initial checks that the launchPath points to an executable file. posix_spawn()
        // can return success even if executing the program fails, eg fork() works but execve()
        // fails, so try and check as much as possible beforehand.
        
        let fsRep = FileManager.default.fileSystemRepresentation(withPath: launchPath)
        var statInfo = stat()
        guard stat(fsRep, &statInfo) == 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
        }
        
        let isRegularFile: Bool = statInfo.st_mode & S_IFMT == S_IFREG
        guard isRegularFile == true else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        }
        
        guard access(fsRep, X_OK) == 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
        }
        // Convert the arguments array into a posix_spawn-friendly format
        
        var args = [launchPath]
        if let arguments = self.p.arguments {
            args.append(contentsOf: arguments)
        }
        
        let argv : UnsafeMutablePointer<UnsafeMutablePointer<Int8>?> = args.withUnsafeBufferPointer {
            let array : UnsafeBufferPointer<String> = $0
            let buffer = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: array.count + 1)
            buffer.initialize(from: array.map { $0.withCString(strdup) }, count: array.count)
            buffer[array.count] = nil
            return buffer
        }
        
        defer {
            for arg in argv ..< argv + args.count {
                free(UnsafeMutableRawPointer(arg.pointee))
            }
            argv.deallocate()
        }
        
        var env: [String: String]
        if let e = p.environment {
            env = e
        } else {
            env = ProcessInfo.processInfo.environment
        }
        
        let nenv = env.count
        let envp = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 1 + nenv)
        envp.initialize(from: env.map { strdup("\($0)=\($1)") }, count: nenv)
        envp[env.count] = nil
        
        defer {
            for pair in envp ..< envp + env.count {
                free(UnsafeMutableRawPointer(pair.pointee))
            }
            envp.deallocate()
        }
        
        var taskSocketPair : [Int32] = [0, 0]
        
        socketpair(AF_UNIX, SOCK_STREAM, 0, &taskSocketPair)
        var context = CFSocketContext()
        context.version = 0
        context.retain = runLoopSourceRetain
        context.release = runLoopSourceRelease
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let socket = CFSocketCreateWithNative( nil, taskSocketPair[0], CFOptionFlags(3), {
            (socket, type, address, data, info )  in
            
//            let p = info?.assumingMemoryBound(to: WrappedProcess.self)
//            let process = p.unsafelyUnwrapped.pointee
            
            
            
            let process: WrappedProcess = Unmanaged.fromOpaque(info!).takeUnretainedValue()
            
            process.processLaunchedCondition.lock()
            while process.isRunning == false {
                process.processLaunchedCondition.wait()
            }
            
            process.processLaunchedCondition.unlock()
            
            var exitCode : Int32 = 0

            var waitResult : Int32 = 0
            
            repeat {
                waitResult = waitpid( process.processIdentifier, &exitCode, 0)
            } while ( (waitResult == -1) && (errno == EINTR) )
            
            if WIFSIGNALED(exitCode) {
                process._terminationStatus = WTERMSIG(exitCode)
                process._terminationReason = .uncaughtSignal
            } else {
                assert(WIFEXITED(exitCode))
                process._terminationStatus = WEXITSTATUS(exitCode)
                process._terminationReason = .exit
            }
            
            // If a termination handler has been set, invoke it on a background thread
            
            if let terminationHandler = process.p.terminationHandler {
                let thread = Thread {
                    terminationHandler(process.p)
                }
                thread.start()
            }
            
            // Set the running flag to false
            process.isRunning = false
            
            // Invalidate the source and wake up the run loop, if it's available
            
            CFRunLoopSourceInvalidate(process.runLoopSource)
            if let runLoop = process.runLoop {
                CFRunLoopWakeUp(runLoop.getCFRunLoop())
            }
            
            CFSocketInvalidate( socket )
            
        }, &context )
        
        CFSocketSetSocketFlags( socket, CFOptionFlags(kCFSocketCloseOnInvalidate))
        
        let source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)
        CFRunLoopAddSource(managerThreadRunLoop?.getCFRunLoop(), source, .defaultMode)
        
        
        let fileActions = UnsafeMutablePointer<posix_spawn_file_actions_t?>.allocate(capacity: 1)
        defer {
            posix_spawn_file_actions_destroy(fileActions)
            fileActions.deallocate()
        }
        try _throwIfPosixError(posix_spawn_file_actions_init(fileActions))
        
        // File descriptors to duplicate in the child process. This allows
        // output redirection to NSPipe or NSFileHandle.
        var adddup2 = [Int32: Int32]()
        
        // File descriptors to close in the child process. A set so that
        // shared pipes only get closed once. Would result in EBADF on OSX
        // otherwise.
        var addclose = Set<Int32>()
        
        var _devNull: FileHandle?
        func devNullFd() throws -> Int32 {
            _devNull = try _devNull ?? FileHandle(forUpdating: URL(fileURLWithPath: "/dev/null", isDirectory: false))
            return _devNull!.fileDescriptor
        }
        
        switch p.standardInput {
        case let pipe as Pipe:
            adddup2[STDIN_FILENO] = pipe.fileHandleForReading.fileDescriptor
            addclose.insert(pipe.fileHandleForWriting.fileDescriptor)
            
        // nil or NullDevice map to /dev/null
        case let handle as FileHandle where handle === FileHandle.nullDevice: fallthrough
        case .none:
            adddup2[STDIN_FILENO] = try devNullFd()
            
        // No need to dup stdin to stdin
        // TODO: Figure out, why on macOS stdin needs to be dup'ed to work correctly
        // case let handle as FileHandle where handle === FileHandle.standardInput: break
            
        case let handle as FileHandle:
            adddup2[STDIN_FILENO] = handle.fileDescriptor
            
        default: break
        }
        
        switch p.standardOutput {
        case let pipe as Pipe:
            adddup2[STDOUT_FILENO] = pipe.fileHandleForWriting.fileDescriptor
            addclose.insert(pipe.fileHandleForReading.fileDescriptor)
            
        // nil or NullDevice map to /dev/null
        case let handle as FileHandle where handle === FileHandle.nullDevice: fallthrough
        case .none:
            adddup2[STDOUT_FILENO] = try devNullFd()
            
        // No need to dup stdout to stdout
        // TODO: Figure out, why on macOS stdout needs to be dup'ed to work correctly
        // case let handle as FileHandle where handle === FileHandle.standardOutput: break
            
        case let handle as FileHandle:
            adddup2[STDOUT_FILENO] = handle.fileDescriptor
            
        default: break
        }
        
        switch p.standardError {
        case let pipe as Pipe:
            adddup2[STDERR_FILENO] = pipe.fileHandleForWriting.fileDescriptor
            addclose.insert(pipe.fileHandleForReading.fileDescriptor)
            
        // nil or NullDevice map to /dev/null
        case let handle as FileHandle where handle === FileHandle.nullDevice: fallthrough
        case .none:
            adddup2[STDERR_FILENO] = try devNullFd()
            
        // No need to dup stderr to stderr
        // TODO: Figure out, why on macOS stderr needs to be dup'ed to work correctly
        // case let handle as FileHandle where handle === FileHandle.standardError: break
            
        case let handle as FileHandle:
            adddup2[STDERR_FILENO] = handle.fileDescriptor
            
        default: break
        }
        
        for (new, old) in adddup2 {
            try _throwIfPosixError(posix_spawn_file_actions_adddup2(fileActions, old, new))
        }
        for fd in addclose.filter({ $0 >= 0 }) {
            try _throwIfPosixError(posix_spawn_file_actions_addclose(fileActions, fd))
        }
        
        var spawnAttrs: posix_spawnattr_t? = nil
        try _throwIfPosixError(posix_spawnattr_init(&spawnAttrs))
        try _throwIfPosixError(posix_spawnattr_setflags(&spawnAttrs, .init(POSIX_SPAWN_CLOEXEC_DEFAULT)))
        
        let fileManager = FileManager()
        let previousDirectoryPath = fileManager.currentDirectoryPath
        if let dir = p.currentDirectoryURL?.path, !fileManager.changeCurrentDirectoryPath(dir) {
            throw _NSErrorWithErrno(errno, reading: true, url: p.currentDirectoryURL)
        }
        
        defer {
            // Reset the previous working directory path.
            fileManager.changeCurrentDirectoryPath(previousDirectoryPath)
        }
        
        // Launch
        var pid = pid_t()
        guard posix_spawn(&pid, launchPath, fileActions, &spawnAttrs, argv, envp) == 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
        }
        
        // Close the write end of the input and output pipes.
        if let pipe = p.standardInput as? Pipe {
            pipe.fileHandleForReading.closeFile()
        }
        if let pipe = p.standardOutput as? Pipe {
            pipe.fileHandleForWriting.closeFile()
        }
        if let pipe = p.standardError as? Pipe {
            pipe.fileHandleForWriting.closeFile()
        }
        
        close(taskSocketPair[1])
        
        self.runLoop = RunLoop.current
        self.runLoopSourceContext = CFRunLoopSourceContext(version: 0,
                                                           info: Unmanaged.passUnretained(self).toOpaque(),
                                                           retain: { return runLoopSourceRetain($0) },
                                                           release: { runLoopSourceRelease($0) },
                                                           copyDescription: nil,
                                                           equal: { return processIsEqual($0, $1) },
                                                           hash: nil,
                                                           schedule: nil,
                                                           cancel: nil,
                                                           perform: { emptyRunLoopCallback($0) })
        self.runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &runLoopSourceContext!)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        isRunning = true
        
        self.processIdentifier = pid
    }
    
    open func waitUntilExit() {
        
        repeat {
            
        } while( self.isRunning == true && RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05)) )
        
        self.runLoop = nil
        self.runLoopSource = nil
    }
}

func runProcessAndWaitForTermination(_ process: Process) throws {
    let wrapped = WrappedProcess.init(p: process)
    try wrapped.run()
    wrapped.waitUntilExit()
}

#else

func runProcessAndWaitForTermination(_ process: Process) throws {
    try process.run()
    process.waitUntilExit()
}

#endif

extension Terraform {
    func invoke(arguments: [String],
                stdin: Any = FileHandle.standardInput,
                stdout: Any = FileHandle.standardOutput,
                stderr: Any = FileHandle.standardError) throws {
        
        let p = Process()
        p.executableURL = terraformExecutable
        p.arguments = arguments
        p.currentDirectoryURL = workingDirectoryURL
        p.standardInput = stdin
        p.standardOutput = stdout
        p.standardError = stderr
        
        var env = ProcessInfo.processInfo.environment
        env.updateValue(terraformExecutable.deletingLastPathComponent().path, forKey: "TF_PLUGIN_CACHE_DIR")
        p.environment = env
        
        try p.run()
        p.waitUntilExit()
    }
}
