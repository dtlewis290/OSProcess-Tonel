"
I represent an external Windows process other than the process in which this Squeak is executing. I maintain information about the state of the external process during and after the lifetime of the process. In particular, I hold the exit status of the process after it completes execution. When the external process changes state (e.g. it exits), the VM signals a Squeak semaphore. A singleton WindowsOSProcessAccessor maintains a process which waits on the semaphore, and sends a changed: #childProcessStatus message to itself, thereby notifying its dependent WindowsOSProcess (a singleton) to check the status of all its ExternalWindowsOSProcess children, and #update: them accordingly.
"
Class {
	#name : #ExternalWindowsOSProcess,
	#superclass : #ExternalOSProcess,
	#instVars : [
		'ppid',
		'exitStatus',
		'handle',
		'threads',
		'commandLine',
		'pwd'
	],
	#category : #'OSProcess-Win32'
}

{ #category : #'instance creation' }
ExternalWindowsOSProcess class >> command: aCommandString [

	"ExternalWindowsOSProcess command: 'SOL'"
	"ExternalWindowsOSProcess command: 'NoSuchProgram'"

	^ (self commandNoEvaluate: aCommandString) value

]

{ #category : #'instance creation' }
ExternalWindowsOSProcess class >> commandNoEvaluate: aCommandString [
	"Answer an instance not yet running."

	"ExternalWindowsOSProcess commandNoEvaluate: 'SOL'"

	^ super new
		commandLine: aCommandString;
		ppid: OSProcess thisOSProcess pid;
		notYetRunning

]

{ #category : #'platform identification' }
ExternalWindowsOSProcess class >> isResponsibleForThisPlatform [
	"Answer true if, for the current platform, this class is responsible for representing
	an OS process other than that in which the Squeak VM is currently running."

	^ self isWindows

]

{ #category : #'instance creation' }
ExternalWindowsOSProcess class >> programName: executableFile arguments: arrayOfStrings initialEnvironment: stringDictionary [
	"This is for protocol compatibility with ExternalUnixOSProcess. For now, just reassemble
	a command line string and ignore the environment argument."

	| commandLine |
	commandLine _ WriteStream on: String new.
	commandLine nextPutAll: executableFile.
	arrayOfStrings ifNotNil:
		[arrayOfStrings do: [:arg | commandLine nextPut: Character space; nextPutAll: arg]].
	^ self commandNoEvaluate: commandLine contents

]

{ #category : #'initialize - release' }
ExternalWindowsOSProcess >> closeHandles [
	"Clean up after process exits."

	self threads do: [:thread | thread closeHandle].
	handle ifNotNil:
		[OSProcess accessor primCloseHandle: handle.
		handle _ nil]

]

{ #category : #accessing }
ExternalWindowsOSProcess >> commandLine [

	^ commandLine
]

{ #category : #accessing }
ExternalWindowsOSProcess >> commandLine: aCommandLineString [

	commandLine _ aCommandLineString
]

{ #category : #'setting run state' }
ExternalWindowsOSProcess >> complete [
	"Process has exited and has been reaped. It no longer exists in the external operating system."

	(threads notNil and: [threads size > 0]) ifTrue: [threads do: [:t | t complete]].
	self closeHandles.
	super complete

]

{ #category : #accessing }
ExternalWindowsOSProcess >> exitStatus [

	^ exitStatus
]

{ #category : #accessing }
ExternalWindowsOSProcess >> exitStatus: status [

	exitStatus _ status

]

{ #category : #accessing }
ExternalWindowsOSProcess >> handle [
	"A Windows HANDLE for this OS process, represented as a ByteArray. The
	handle should be closed when the process exits."

	^ handle
]

{ #category : #accessing }
ExternalWindowsOSProcess >> handle: aHandleObject [
	"A Windows HANDLE for this OS process, represented as a ByteArray. The
	handle should be closed when the process exits."

	handle _ aHandleObject
]

{ #category : #accessing }
ExternalWindowsOSProcess >> ppid [

	^ ppid

]

{ #category : #accessing }
ExternalWindowsOSProcess >> ppid: aProcessID [

	ppid _ aProcessID
]

{ #category : #printing }
ExternalWindowsOSProcess >> printOn: aStream [

	self commandLine isNil
		ifTrue:
			[^ super printOn: aStream]
		ifFalse:
			[aStream
				nextPutAll: 'a ';
				nextPutAll: self class name, ' with pid ';
				nextPutAll: self pid printString.
			(self isComplete and: [handle isNil])
				ifTrue:
					[aStream nextPutAll: ' (handle closed)']
				ifFalse:
					[aStream nextPutAll: ' handle ';
						nextPutAll: (handle isNil
							ifTrue: [handle printString]
							ifFalse: [handle asArray printString])].
			aStream
				nextPutAll: ' on ''';
				nextPutAll: commandLine;
				nextPutAll: ''' (';
				nextPutAll: self runState asString;
				nextPut: $)]


]

{ #category : #accessing }
ExternalWindowsOSProcess >> pwd [
	"Answer the current working directory string."

	^ pwd
]

{ #category : #accessing }
ExternalWindowsOSProcess >> pwd: pathString [
	"The current working directory string."

	pwd _ pathString
]

{ #category : #accessing }
ExternalWindowsOSProcess >> threads [
	"One or more threads of execution within the OS process"

	^ threads ifNil: [threads _ OrderedCollection new]

]

{ #category : #updating }
ExternalWindowsOSProcess >> update: aParameter [ 

	| accessible stat |
	aParameter == #runState
		ifTrue:
			["Has the process exited?"
	 		stat _ self accessor primGetExitStatusForHandle: self handle.
			stat ifNotNil: [self complete closeHandles exitStatus: stat]].
	aParameter == #accessibility
		ifTrue: ["Does the process still exist, and is it reachable?"
			((accessible _ self isAccessible) notNil and: [accessible])
				ifFalse: [self isRunning ifTrue: [self unknownRunState]]].
	super update: aParameter

]

{ #category : #evaluating }
ExternalWindowsOSProcess >> value [
	"Start the external process"

	| procInfo mainThread |
	self isNotYetRunning ifTrue:
		[procInfo _ OSProcess accessor primCommand: self commandLine.
		procInfo isNil
			ifTrue:
				[self initialStdErr nextPutAll: 'cannot execute ', self commandLine; cr.
				self exitStatus: #cannotExecuteCommandLine.
				"FIXME: Close the OSPipes now, otherwise the image will block on a read"
				self closeStreams.
				[self complete] fork "defer execution so OSPipes stay in place for now"]
			ifFalse:
				[self pid: (procInfo at: 3).
				self handle: (procInfo at: 1).
				mainThread _ WindowsThread
						threadID: (procInfo at: 4)
						handle: (procInfo at: 2)
						running: true.
				self threads add: mainThread.
 				self running.
				OSProcess thisOSProcess registerChildProcess: self.
				"FIXME: Close the initial pipe handles. For now, I have not implemented
				passing these to the child, and there is no support yet for nonblocking
				Windows OS pipes. Once those are available, this method needs to change
				to support."
				self closeStreams]].

]
