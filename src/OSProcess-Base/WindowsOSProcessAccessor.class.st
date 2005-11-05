"
I provide access to an operating system process, such as the process in which the Squeak VM is currently running. I am based on the Win32 process model for Windows and Windows NT.
"
Class {
	#name : #WindowsOSProcessAccessor,
	#superclass : #OSProcessAccessor,
	#instVars : [
		'sigChldSemaphore',
		'semaIndex',
		'grimReaper',
		'childWatcherThread'
	],
	#category : #'OSProcess-Win32'
}

{ #category : #'platform identification' }
WindowsOSProcessAccessor class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for the
	Squeak VM running on the current platform."

	^ OSProcess isWindows

]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> activeHandles [
	"Answer an Array of handles for all children that are believed to be running."

	^ OSProcess thisOSProcess activeHandles

]

{ #category : #testing }
WindowsOSProcessAccessor >> canAccessChildProcess: anExternalProcess [
	"Is the child process still there? Maybe not if we have restarted the image
	and anExternalProcess refers to a process which died while we were not
	watching."

	| handle |
	^ (handle _ anExternalProcess handle) notNil
		ifTrue: [self primCanAccessChildProcess: handle]
		ifFalse: [false]

]

{ #category : #testing }
WindowsOSProcessAccessor >> canAccessSystem [
	"Answer true if it is possible to access the external process, else false. Failure
	to access the external process is probably due to lack of a UnixOSProcessPlugin
	module."

	^ self primGetPid notNil

]

{ #category : #accessing }
WindowsOSProcessAccessor >> childWatcherThread [
	"A thread which signals my sigChldSemaphore when any child process exits."

	^ childWatcherThread
]

{ #category : #accessing }
WindowsOSProcessAccessor >> childWatcherThread: aThreadObject [
	"A thread which signals my sigChldSemaphore when any child process exits."

	childWatcherThread _ aThreadObject

]

{ #category : #'initialize - release' }
WindowsOSProcessAccessor >> finalize [
	"Clean up grimReaper and associated semaphore."

	grimReaper ifNotNil:
			[grimReaper terminate.
			grimReaper _ nil].
	sigChldSemaphore ifNotNil:
			[Smalltalk unregisterExternalObject: sigChldSemaphore.
			sigChldSemaphore _ nil].
	semaIndex _ nil

]

{ #category : #'external process access' }
WindowsOSProcessAccessor >> getMainThread [
	"Answer the main thread of this OS process. The handle for this thread is a
	pseudo-handle, and cannot be used to terminate the thread."

	"OSProcess accessor getMainThread"

	^ WindowsThread threadID: self primGetPid handle: self primGetPidHandle running: true

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> getStdErr [
	"Answer an IO handle (representing a SQFile data structure in interp.c) for the standard
	error for the OS process in which I am currently executing, or nil if the IO handle
	cannot be obtained."

	"OSProcess accessor getStdErr"

	| error |
	error _ self primGetStdErrorForSession: self sessionIdentifier.
	^ (error notNil and: [error last])
		ifTrue: [self ioAccessorFromSQFile: error first]
		ifFalse: [nil]

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> getStdErrHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard error for the
	OS process in which I am currently executing."

	^ self ioAccessorFromSQFile: self getStdErr

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> getStdIn [
	"Answer an IO handle (representing a SQFile data structure in interp.c) for the standard
	input for the OS process in which I am currently executing, or nil if the IO handle
	cannot be obtained."

	"OSProcess accessor getStdIn"

	| input |
	input _ self primGetStdInputForSession: self sessionIdentifier.
	^ (input notNil and: [input last])
		ifTrue: [self ioAccessorFromSQFile: input first]
		ifFalse: [nil]

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> getStdInHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard input for the
	OS process in which I am currently executing."

	^ self ioAccessorFromSQFile: self getStdIn

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> getStdOut [
	"Answer an IO handle (representing a SQFile data structure in interp.c) for the standard
	output for the OS process in which I am currently executing, or nil if the IO handle
	cannot be obtained."

	"OSProcess accessor getStdOut"

	| output |
	output _ self primGetStdOutputForSession: self sessionIdentifier.
	^ (output notNil and: [output last])
		ifTrue: [self ioAccessorFromSQFile: output first]
		ifFalse: [nil]

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> getStdOutHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard output for the
	OS process in which I am currently executing."

	^ self ioAccessorFromSQFile: self getStdOut

]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> grimReaperProcess [
	"This is a process which waits for the death of a child OSProcess, and 
	informs any dependents of the change."

	grimReaper ifNil: [grimReaper _ [
				[self sigChldSemaphoreSet wait.
				self changed: #childProcessStatus] repeat] fork].
	^ grimReaper
]

{ #category : #'initialize - release' }
WindowsOSProcessAccessor >> initialize [
	"Create and register a semaphore to be used for signaling external process exits"

	super initialize.
	self sigChldSemaphoreSet.
	self grimReaperProcess

]

{ #category : #testing }
WindowsOSProcessAccessor >> isExecutable: aPathName [
	"Answer true if file at aPathName has execute permission for this process."

	"FIXME: Default to true for Windows"

	^ true


]

{ #category : #'nonblocking read' }
WindowsOSProcessAccessor >> lastReadFor: aSemaphoreIndex [
	"A character has been read into an external buffer corresponding to aSemaphoreIndex,
	and is now available. Answer integer value of the character, or nil if no character
	was read, or -1 if an error occurred on the read."

	| c readResult |
	readResult _ Array new: 3.
	c _ self primLastReadFor: aSemaphoreIndex storeIn: readResult.
	(c < 1) ifTrue: [self error: 'primLastReadFor: error, returned negative value'].
	^ c

]

{ #category : #'nonblocking read' }
WindowsOSProcessAccessor >> lastReadFor: aSemaphoreIndex storeIn: aThreeElementArray [
	"A character has been read into an external buffer corresponding to aSemaphoreIndex,
	and is now available. Answer integer value of the character, or nil if no character
	was read, or -1 if an error occurred on the read. The results of the read call are
	stored in aThreeElementArray as a side effect."

	^ self primLastReadFor: aSemaphoreIndex storeIn: aThreeElementArray

]

{ #category : #'nonblocking read' }
WindowsOSProcessAccessor >> nextFrom: aFileStream signaling: aSemaphoreIndex [
	"Read the next character from aFileStream into a buffer in the VM. When the read completes,
	signal the specified Semaphore to notify that the character is available."

	| sqFile |
	sqFile _ UseIOHandle
				ifTrue: [aFileStream ioHandle handle]
				ifFalse: [aFileStream fileID].
	^ self primNextFrom: sqFile signaling: aSemaphoreIndex

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> openStdErr [
	"Answer an IO handle (representing a SQFile data structure in interp.c) for the standard
	error for the OS process in which I am currently executing. Open a console if necessary
	to make standard error available."

	"OSProcess accessor openStdErr"

	| error |
	error _ self primGetStdErrorForSession: self sessionIdentifier.
	error ifNil: [^ nil].
	error last
		ifFalse:
			[self primAllocConsole.
			error _ self primGetStdOutputForSession: self sessionIdentifier].
	^ self ioAccessorFromSQFile: error first

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> openStdIn [
	"Answer an IO handle (representing a SQFile data structure in interp.c) for the standard
	input for the OS process in which I am currently executing. Open a console if necessary
	to make standard input available."

	"OSProcess accessor openStdIn"

	| input |
	input _ self primGetStdInputForSession: self sessionIdentifier.
	input ifNil: [^ nil].
	input last
		ifFalse:
			[self primAllocConsole.
			input _ self primGetStdOutputForSession: self sessionIdentifier].
	^ self ioAccessorFromSQFile: input first

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> openStdOut [
	"Answer an IO handle (representing a SQFile data structure in interp.c) for the standard
	output for the OS process in which I am currently executing. Open a console if necessary
	to make standard input available."

	"OSProcess accessor openStdOut"

	| output |
	output _ self primGetStdOutputForSession: self sessionIdentifier.
	output ifNil: [^ nil].
	output last
		ifFalse:
			[self primAllocConsole.
			output _ self primGetStdOutputForSession: self sessionIdentifier].
	^ self ioAccessorFromSQFile: output first

]

{ #category : #'plugin identification' }
WindowsOSProcessAccessor >> osppModuleName [
	"Answer a string containing the module name string for the OSPP plugin."

	"OSProcess accessor osppModuleName"

	^ self primOSProcessPluginModuleName

]

{ #category : #'plugin identification' }
WindowsOSProcessAccessor >> osppModuleVersionString [
	"Answer a string containing the version string for the OSPP plugin."

	"OSProcess accessor osppModuleVersionString"

	^ self primOSProcessPluginModuleVersionString

]

{ #category : #console }
WindowsOSProcessAccessor >> primAllocConsole [
	"Allocate a console if not already allocated."

	"OSProcess accessor primAllocConsole"

	<primitive: 'primitiveAllocConsole' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primBufferValuesAt: aSemaphoreIndex [
	"For debugging only. Answer the current values of readCharBufferArray,
	readCharCountArray, and readCharStatusArray at index, an integer corresponding
	to a semaphore for one read handler thread. Answer an Array with the buffered
	character, the character count, and the status value."

	"OSProcess accessor primBufferValuesAt: 1"

	<primitive: 'primitiveBufferValuesAt' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> primCanAccessChildProcess: handleObject [
	"Answer true if the OS process represented by a HANDLE can be accessed by this OS process."

	<primitive: 'primitiveCanAccessChildProcess' module: 'Win32OSProcessPlugin'>

	^ false
]

{ #category : #handles }
WindowsOSProcessAccessor >> primCloseHandle: handleObject [
	"Close the specified handle, which may refer to a process, a thread, or
	some other Win32 object."

	"| procInfo |
	procInfo _ OSProcess accessor primCommand: 'SOL'.
	OSProcess accessor primCloseHandle: procInfo first"

	<primitive: 'primitiveCloseHandle' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #deprecated }
WindowsOSProcessAccessor >> primCommand: commandString [
	"Run a command in a new external process. Answer a result array with
	hProcess, hThread, dwProcessId, dwThreadId.

	This primitive has been replaced by #primCommand:stdIn:stdOut:stdErr:, and
	will be removed in future versions of OSProcess."

	"OSProcess accessor primCommand: 'C:\WINDOWS\SOL'"
	"OSProcess accessor primCommand: 'SOL'"
	"OSProcess accessor primCommand: 'NoSuchProgram'"

	<primitive: 'primitiveCommand' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'process creation' }
WindowsOSProcessAccessor >> primCommand: commandString stdIn: inputFileIoHandle stdOut: outputFileIoHandle stdErr: errorFileIoHandle [

	"Run a command in a new external process. The standard input, output and error
	stream handles are sqFile byte arrays (not Win32 HANDLE arrays), and may be nil.
	Answer a result array with hProcess, hThread, dwProcessId, dwThreadId."

	"OSProcess accessor primCommand: 'C:\WINDOWS\SOL' stdIn: nil stdOut: nil stdErr: nil"
	"OSProcess accessor primCommand: 'SOL' stdIn: nil stdOut: nil stdErr: nil"
	"OSProcess accessor primCommand: 'NoSuchProgram' stdIn: nil stdOut: nil stdErr: nil"
	"OSProcess accessor primCommand: 'SOL' stdIn: (FileStream fileNamed: 'output.tmp') fileID stdOut: nil stdErr: nil"

	<primitive: 'primitiveCommandWithInputOutputError' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'pipe open' }
WindowsOSProcessAccessor >> primCreatePipe [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveCreatePipe' module: 'Win32OSProcessPlugin'>
	^ self primMakePipe "try the older deprecated version"
]

{ #category : #'pipe open' }
WindowsOSProcessAccessor >> primCreatePipeWithSessionIdentifier: aByteArray [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveCreatePipeWithSessionIdentifier' module: 'Win32OSProcessPlugin'>
	^ self primMakePipeWithSessionIdentifier: aByteArray "try the older deprecated version"
]

{ #category : #console }
WindowsOSProcessAccessor >> primFreeConsole [
	"Deallocate the console if allocated."

	"OSProcess accessor primFreeConsole"

	<primitive: 'primitiveFreeConsole' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'external process access' }
WindowsOSProcessAccessor >> primGetCurrentWorkingDirectory [
	"Call getcwd() to get the current working directory."

	"OSProcess accessor primGetCurrentWorkingDirectory"

	<primitive: 'primitiveGetCurrentWorkingDirectory' module: 'Win32OSProcessPlugin'>
	^ nil

]

{ #category : #'external process access' }
WindowsOSProcessAccessor >> primGetEnvironmentStrings [
	"Answer the environment block in the form of an Array of Strings. The
	caller is expected to parse the strings into a dictionary of keys and values."

	<primitive: 'primitiveGetEnvironmentStrings' module: 'Win32OSProcessPlugin'>
	^ nil

]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> primGetExitStatusForHandle: handleObject [
	"Answer the exit status for the process represented by a HANDLE. Fail if
	the process is still active, or if the GetExitCodeProcess call fails."

	"| procInfo |
	procInfo _ OSProcess accessor primCommand: 'SOL'.
	(Delay forSeconds: 5) wait.
	OSProcess accessor primGetExitStatusForHandle: procInfo first"

	<primitive: 'primitiveGetExitStatusForHandle' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'external process access' }
WindowsOSProcessAccessor >> primGetMainThreadHandle [
	"Answer a pseudo-handle for my main thread."

	"OSProcess accessor primGetMainThreadHandle"

	<primitive: 'primitiveGetMainThreadHandle' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
WindowsOSProcessAccessor >> primGetMainThreadID [
	"Answer the ID of my main thread."

	<primitive: 'primitiveGetMainThreadID' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
WindowsOSProcessAccessor >> primGetPid [
	"Answer the OS process ID for the OS process in which I am currently executing."

	<primitive: 'primitiveGetPid' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
WindowsOSProcessAccessor >> primGetPidHandle [
	"Answer the pseudo-handle for my OS process"

	"OSProcess accessor primGetPidHandle"

	<primitive: 'primitiveGetPidHandle' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'session identification' }
WindowsOSProcessAccessor >> primGetSession [
	"Answer the unique identifier for this session of Smalltalk running in this OS Process."

	"OSProcess accessor primGetSession"

	<primitive: 'primitiveGetSession' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primGetStdErrorForSession: sessionIdentifierByteArray [
	"Answer a two element array containing the sqFile data structure representing
	standard error stream for my OS process, and a flag (true or false) to indicate
	whether the sqFile data structure contains a valid HANDLE. If no standard error
	stream is available for this OS process, the sqFile data structure will contain an
	invalid HANDLE value, which will result in failures on subsequent accesses."

	"OSProcess accessor primGetStdError"

	<primitive: 'primitiveGetStdError' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primGetStdInputForSession: sessionIdentifierByteArray [
	"Answer a two element array containing the sqFile data structure representing
	standard input stream for my OS process, and a flag (true or false) to indicate
	whether the sqFile data structure contains a valid HANDLE. If no standard input
	stream is available for this OS process, the sqFile data structure will contain an
	invalid HANDLE value, which will result in failures on subsequent accesses."

	"OSProcess accessor primGetStdInput"

	<primitive: 'primitiveGetStdInput' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primGetStdOutputForSession: sessionIdentifierByteArray [
	"Answer a two element array containing the sqFile data structure representing
	standard output stream for my OS process, and a flag (true or false) to indicate
	whether the sqFile data structure contains a valid HANDLE. If no standard output
	stream is available for this OS process, the sqFile data structure will contain an
	invalid HANDLE value, which will result in failures on subsequent accesses."

	"OSProcess accessor primGetStdOutput"

	<primitive: 'primitiveGetStdOutput' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primLastReadFor: aSemaphoreIndex [
	"A character has been read into an external buffer corresponding to aSemaphoreIndex,
	and is now available. Answer integer value of the character, or nil if no character
	was read, or -1 if an error occurred on the read."

	<primitive: 'primitiveLastReadFor' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primLastReadFor: aSemaphoreIndex storeIn: aThreeElementArray [
	"A character has been read into an external buffer corresponding to aSemaphoreIndex,
	and is now available. Answer integer value of the character, or nil if no character
	was read, or -1 if an error occurred on the read. Contents of the aThreeElementArray
	will be status of the read call, character read, and character count (which should
	always be 1)."

	<primitive: 'primitiveLastReadForStoreIn' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #deprecated }
WindowsOSProcessAccessor >> primMakePipe [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveMakePipe' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #deprecated }
WindowsOSProcessAccessor >> primMakePipeWithSessionIdentifier: aByteArray [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveMakePipeWithSessionIdentifier' module: 'Win32OSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primNextFrom: anIOHandle signaling: aSemaphoreIndex [
	"Read the next character from anIOHandle (a SQFile struct) into a buffer in the VM. When
	the read completes, signal the specified Semaphore to notify that the character is available."

	<primitive: 'primitiveNextFromSignaling' module: 'Win32OSProcessPlugin'>

	^ nil


]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primOSProcessPluginModuleName [
	"Answer a string containing the module name string for the OSPP plugin."

	"OSProcess accessor primOSProcessPluginModuleName"

	<primitive: 'primitiveModuleName' module: 'Win32OSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
WindowsOSProcessAccessor >> primOSProcessPluginModuleVersionString [
	"Answer a string containing the version string for the OSPP plugin."

	"OSProcess accessor primOSProcessPluginModuleVersionString"

	<primitive: 'primitiveVersionString' module: 'Win32OSProcessPlugin'>
	^ nil

]

{ #category : #testing }
WindowsOSProcessAccessor >> primOneShot [
	"Anwer true the first time this is called in a Squeak session, and false thereafter."

	"OSProcess accessor primOneShot"

	<primitive: 'primitiveOneShot' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #handles }
WindowsOSProcessAccessor >> primSetStdErr: anIOHandle [
	"Set the standard error handle to that of anIOHandle, where anIOHandle is a
	ByteArray representation of a SQFile structure."

	<primitive: 'primitiveSetStdErr' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #handles }
WindowsOSProcessAccessor >> primSetStdIn: anIOHandle [
	"Set the standard input handle to that of anIOHandle, where anIOHandle is a
	ByteArray representation of a SQFile structure."

	<primitive: 'primitiveSetStdIn' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #handles }
WindowsOSProcessAccessor >> primSetStdOut: anIOHandle [
	"Set the standard output handle to that of anIOHandle, where anIOHandle is a
	ByteArray representation of a SQFile structure."

	<primitive: 'primitiveSetStdOut' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> primSetWaitForAnyProcessExit: arrayOfProcessHandleObjects thenSignalSemaphoreWithIndex: index [
	"Set up a thread to wait for a process HANDLE to exit, then signal the Semaphore
	at index. This provides asychronous notification of an external process exit."

	<primitive: 'primitiveSetWaitForAnyProcessExitThenSignalSemaphoreWithIndex' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> primTerminateThread: aThreadHandle [
	"Kill the thread. No cleanup is performed, so use with caution for a thread which
	is (for example) manipulating a mutex. Answer true for success, else false."

	<primitive: 'primitiveTerminateThread' module: 'Win32OSProcessPlugin'>

	^ nil
]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> restartChildWatcherThread: arrayOfProcessHandleObjects [
	"Start a new child watcher thread. If a thread is alread active, terminate
	it before starting a new one."


	self childWatcherThread ifNotNil: [childWatcherThread terminate].
	self childWatcherThread: (self setWaitForAnyProcessExit: arrayOfProcessHandleObjects).
	^ childWatcherThread

]

{ #category : #accessing }
WindowsOSProcessAccessor >> semaIndex [
	"Index of the registered Semaphore"

	semaIndex ifNil: [self initialize].
	^ semaIndex
]

{ #category : #'file control' }
WindowsOSProcessAccessor >> setBlocking: anIOHandle [
	"Convert anIOHandle to an SQFile data structure and call primitive to set for blocking I/O."

	"FIXME: need to implement this for Win32"
	"self notify: 'there is no general mechanism to set blocking IO on Win32'"

]

{ #category : #'file control' }
WindowsOSProcessAccessor >> setNonBlocking: anIOHandle [
	"Convert anIOHandle to an SQFile data structure and call primitive to set it non-blocking."

	"FIXME: need to implement this for Win32"
	"self notify: 'there is no general mechanism to set nonblocking IO on Win32'"


]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> setStdErr: aFileStream [
	"Set the standard error handle for this OSProcess to be that of aFileStream"

	"| fs |
	fs _ FileStream fileNamed: 'stdError.tmp'.
	OSProcess accessor setStdErr: fs"

	| sqFile |
	aFileStream ifNil: [^ false].
	sqFile _ UseIOHandle
				ifTrue: [aFileStream ioHandle handle]
				ifFalse: [aFileStream fileID].
	^ self primSetStdErr: sqFile

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> setStdIn: aFileStream [
	"Set the standard input handle for this OSProcess to be that of aFileStream"

	"| fs |
	fs _ FileStream fileNamed: 'stdInput.tmp'.
	fs nextPutAll: 'this is a line of text'; cr.
	fs position: 0.
	OSProcess accessor setStdIn: fs"

	| sqFile |
	aFileStream ifNil: [^ false].
	sqFile _ UseIOHandle
				ifTrue: [aFileStream ioHandle handle]
				ifFalse: [aFileStream fileID].
	^ self primSetStdIn: sqFile

]

{ #category : #'standard IO handles' }
WindowsOSProcessAccessor >> setStdOut: aFileStream [
	"Set the standard output handle for this OSProcess to be that of aFileStream"

	"| fs |
	fs _ FileStream fileNamed: 'stdOutput.tmp'.
	OSProcess accessor setStdOut: fs"

	| sqFile |
	aFileStream ifNil: [^ false].
	sqFile _ UseIOHandle
				ifTrue: [aFileStream ioHandle handle]
				ifFalse: [aFileStream fileID].
	^ self primSetStdOut: sqFile

]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> setWaitForAnyProcessExit: arrayOfProcessHandleObjects [
	"Set up a thread to wait for a process HANDLE to exit, then signal the Semaphore
	at index. This provides asychronous notification of an external process exit. The
	caller should close the thread handle when it is no longer needed."

	"OSProcess command: 'SOL'.
	OSProcess accessor setWaitForAnyProcessExit: OSProcess thisOSProcess activeHandles."

	| threadInfo |
	arrayOfProcessHandleObjects isEmpty ifTrue: [^ nil].
	threadInfo _ self
		primSetWaitForAnyProcessExit: arrayOfProcessHandleObjects
		thenSignalSemaphoreWithIndex: self semaIndex.
	^ WindowsThread
		threadID: threadInfo last
		handle: threadInfo first
		running: true


]

{ #category : #'child process management' }
WindowsOSProcessAccessor >> sigChldSemaphoreSet [

	sigChldSemaphore ifNil:
		[sigChldSemaphore _ Semaphore new.
		semaIndex _ Smalltalk registerExternalObject: sigChldSemaphore].
	^ sigChldSemaphore
]
