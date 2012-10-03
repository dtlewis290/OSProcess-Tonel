"
I represent an external Unix process other than the process in which this Squeak is executing. I maintain information about the state of the external process during and after the lifetime of the process. In particular, I hold the exit status of the process after it completes execution. When the external process changes state (e.g. it exits), the VM signals a Squeak semaphore. A singleton UnixProcessAccessor maintains a process which waits on the semaphore, and sends a changed: #childProcessStatus message to itself, thereby notifying its dependent UnixProcess (a singleton) to check the status of all its ExternalUnixProcess children, and #update: them accordingly.
"
Class {
	#name : #ExternalUnixOSProcess,
	#superclass : #ExternalOSProcess,
	#instVars : [
		'ppid',
		'pwd',
		'exitStatus',
		'programName',
		'arguments',
		'initialEnvironment'
	],
	#category : #'OSProcess-Unix'
}

{ #category : #shells }
ExternalUnixOSProcess class >> bashShellPath [
	"A more full-featured shell from the Free Software Foundation"

	| path |
	path := '/bin/bash'.
	(FileDirectory default fileExists: path)
		ifTrue: [^ path]
		ifFalse: [self notify: path, ' not found']
]

{ #category : #'instance creation' }
ExternalUnixOSProcess class >> command: aCommandString [

	"ExternalUnixOSProcess command: 'ls -l /etc'"

	^ self forkAndExec: self defaultShellPath
		arguments: (Array with: '-c' with: aCommandString)
		environment: nil
]

{ #category : #shells }
ExternalUnixOSProcess class >> defaultShellPath [
	"Default shell to run"

	| path |
	path := '/bin/sh'.
	((FileDirectory on: '/bin') fileNames includes: 'sh') "work around bug in symlink resolution for some VMs"
		ifTrue: [^ path]
		ifFalse: [self notify: path, ' not found']
]

{ #category : #'instance creation' }
ExternalUnixOSProcess class >> exec: programName [
	"Run a program in an external OS process, and answer an instance of myself
	which represents the external process."

	^ self forkAndExec: programName

]

{ #category : #'instance creation' }
ExternalUnixOSProcess class >> forkAndExec: executableFile [

	"ExternalUnixOSProcess forkAndExec: '/bin/ls'"

	^ super new
		programName: executableFile;
		initialize;
		forkChild

]

{ #category : #'instance creation' }
ExternalUnixOSProcess class >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary [ 
	"Run a program in an external OS process, and answer an instance of 
	myself which represents the external process."

	"ExternalUnixOSProcess forkAndExec: '/bin/ls' arguments: (Array with: '-l') environment: (UnixProcess env)"

	^ super new
		programName: executableFile;
		arguments: arrayOfStrings;
		initialEnvironment: stringDictionary;
		initialize;
		forkChild

]

{ #category : #'instance creation' }
ExternalUnixOSProcess class >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [
	"Run a program in an external OS process, and answer an instance of myself
	which represents the external process."

	"ExternalUnixOSProcess
		forkAndExec: '/bin/ls'
		arguments: (Array with: '-l')
		environment: (UnixProcess env)
		descriptors: nil"

	| proc |
	proc := super new
		programName: executableFile;
		arguments: arrayOfStrings;
		initialEnvironment: stringDictionary.
	arrayOf3Streams ifNotNil:
		[proc initialStdIn: (arrayOf3Streams at: 1).
		proc initialStdOut: (arrayOf3Streams at: 2).
		proc initialStdErr: (arrayOf3Streams at: 3)].
	^ proc initialize forkChild

]

{ #category : #'instance creation' }
ExternalUnixOSProcess class >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams workingDir: pathString [
	"Run a program in an external OS process, and answer an instance of myself
	which represents the external process."

	"ExternalUnixOSProcess forkAndExec: '/bin/ls' arguments: nil environment: nil descriptors: nil workingDir: '/etc'"

	| proc |
	proc := super new
		programName: executableFile;
		arguments: arrayOfStrings;
		initialEnvironment: stringDictionary.
	arrayOf3Streams ifNotNil:
		[proc initialStdIn: (arrayOf3Streams at: 1).
		proc initialStdOut: (arrayOf3Streams at: 2).
		proc initialStdErr: (arrayOf3Streams at: 3)].
	pathString ifNotNil: [proc pwd: pathString].
	^ proc initialize forkChild

]

{ #category : #'platform identification' }
ExternalUnixOSProcess class >> isResponsibleForThisPlatform [
	"Answer true if, for the current platform, this class is responsible for representing
	an OS process other than that in which the Squeak VM is currently running."

	^ self isUnix

]

{ #category : #'instance creation' }
ExternalUnixOSProcess class >> programName: executableFile arguments: arrayOfStrings initialEnvironment: stringDictionary [
	"Answer an instance not yet running."

	^ super new
		programName: executableFile;
		arguments: arrayOfStrings;
		initialEnvironment: stringDictionary

]

{ #category : #shells }
ExternalUnixOSProcess class >> remoteShellPath [
	"A remote shell processor. This may need to be edited for different systems."

	| path |
	path := '/usr/bin/rsh'.
	(FileDirectory default fileExists: path)
		ifTrue: [^ path]
		ifFalse: [self notify: path, ' not found']
]

{ #category : #shells }
ExternalUnixOSProcess class >> tkShellPath [
	"The wish command shell for Tk/Tcl. This tends to be installed in a wide variety
	of places, so you may need to edit this method for your system."

	| path |
	path := '/usr/bin/wish'.
	(FileDirectory default fileExists: path)
		ifTrue: [^ path]
		ifFalse: [self notify: path, ' not found']
]

{ #category : #comparing }
ExternalUnixOSProcess >> = processProxy [
	"True if this is a proxy that represents the same OS process as processProxy"

	^ ((self isKindOf: ExternalUnixOSProcess)
			and: [pid = processProxy pid])
				and: [ppid = processProxy ppid]
]

{ #category : #accessing }
ExternalUnixOSProcess >> arguments [

	^ arguments
]

{ #category : #accessing }
ExternalUnixOSProcess >> arguments: arrayOfArgumentStrings [

	arguments := arrayOfArgumentStrings
]

{ #category : #accessing }
ExternalUnixOSProcess >> exitStatus [

	^ exitStatus

]

{ #category : #accessing }
ExternalUnixOSProcess >> exitStatus: anInteger [

	exitStatus := anInteger

]

{ #category : #'initialize - release' }
ExternalUnixOSProcess >> forkChild [
	"Start the external OS process. All instances variables except for pid  
	should have been set. The pid will be set following creation of the new 
	external process. Creating a child process is the responsibility of the
	currently executing OS process, so request it to do so on behalf of this
	instance of ExternalUnixOSProcess."

	^ OSProcess thisOSProcess
		processProxy: self
		forkAndExec: programName
		arguments: arguments
		environment: initialEnvironment
		descriptors: (Array
				with: initialStdIn
				with: initialStdOut
				with: initialStdErr)

]

{ #category : #comparing }
ExternalUnixOSProcess >> hash [

	^ (pid ifNil: [self identityHash]) + (ppid ifNil: [self identityHash])

]

{ #category : #accessing }
ExternalUnixOSProcess >> initialEnvironment [

	^ initialEnvironment
]

{ #category : #accessing }
ExternalUnixOSProcess >> initialEnvironment: aDictionary [

	initialEnvironment := aDictionary
]

{ #category : #'initialize - release' }
ExternalUnixOSProcess >> initialize [

	super initialize.
	^ self setDefaults

]

{ #category : #accessing }
ExternalUnixOSProcess >> pid [

	^ pid

]

{ #category : #accessing }
ExternalUnixOSProcess >> pid: aPid [

	pid := aPid

]

{ #category : #accessing }
ExternalUnixOSProcess >> ppid [

	^ ppid

]

{ #category : #accessing }
ExternalUnixOSProcess >> ppid: aPid [

	ppid := aPid

]

{ #category : #printing }
ExternalUnixOSProcess >> printOn: aStream [

	self programName isNil
		ifTrue:
			[^ super printOn: aStream]
		ifFalse:
			[aStream
				nextPutAll: 'an ';
				nextPutAll: self class name, ' with pid ';
				nextPutAll: self pid printString;
				nextPutAll: ' on ';
				nextPutAll: programName;
				nextPutAll: ' (';
				nextPutAll: self runState asString.
			self isComplete
				ifTrue: [aStream nextPutAll: ', ';
					nextPutAll: (UnixProcessExitStatus for: exitStatus) printString].
			aStream nextPut: $)].

]

{ #category : #accessing }
ExternalUnixOSProcess >> programName [

	^ programName
]

{ #category : #accessing }
ExternalUnixOSProcess >> programName: fileName [

	programName := fileName
]

{ #category : #accessing }
ExternalUnixOSProcess >> pwd [

	pwd ifNil: [pwd := self accessor primGetCurrentWorkingDirectory].
	^ pwd
]

{ #category : #accessing }
ExternalUnixOSProcess >> pwd: pathString [

	pwd := pathString
]

{ #category : #'initialize - release' }
ExternalUnixOSProcess >> setDefaults [

	| this |
	this := OSProcess thisOSProcess.
	initialEnvironment ifNil: [self initialEnvironment: this environment].
	initialStdIn ifNil: [self initialStdIn: this stdIn].
	initialStdOut ifNil: [self initialStdOut: this stdOut].
	initialStdErr ifNil: [self initialStdErr: this stdErr].	
	self pwd


]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigabrt [
	"Send a SIGABRT signal to the external process which I represent."

	OSProcess thisOSProcess sigabrt: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigalrm [
	"Send a SIGALRM signal to the external process which I represent."

	OSProcess thisOSProcess sigalrm: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigchld [
	"Send a SIGCHLD signal to the external process which I represent."

	OSProcess thisOSProcess sigchld: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigcont [
	"Send a SIGCONT signal to the external process which I represent."

	OSProcess thisOSProcess sigcont: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sighup [
	"Send a SIGHUP signal to the external process which I represent."

	OSProcess thisOSProcess sighup: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigint [
	"Send a SIGINT signal to the external process which I represent."

	OSProcess thisOSProcess sigint: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigkill [
	"Send a SIGKILL signal to the external process which I represent."

	OSProcess thisOSProcess sigkill: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigpipe [
	"Send a SIGPIPE signal to the external process which I represent."

	OSProcess thisOSProcess sigpipe: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigquit [
	"Send a SIGQUIT signal to the external process which I represent."

	OSProcess thisOSProcess sigquit: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigstop [
	"Send a SIGSTOP signal to the external process which I represent."

	OSProcess thisOSProcess sigstop: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigterm [
	"Send a SIGTERM signal to the external process which I represent."

	OSProcess thisOSProcess sigterm: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigusr1 [
	"Send a SIGUSR1 signal to the external process which I represent."

	OSProcess thisOSProcess sigusr1: self
]

{ #category : #'OS signal sending' }
ExternalUnixOSProcess >> sigusr2 [
	"Send a SIGUSR2 signal to the external process which I represent."

	OSProcess thisOSProcess sigusr2: self
]

{ #category : #testing }
ExternalUnixOSProcess >> succeeded [

	^ self isComplete and: [self exitStatus == 0]
]

{ #category : #'terminating child' }
ExternalUnixOSProcess >> terminate [
	"Kill the child process which I represent."

	self sigkill.
	self finalize


]

{ #category : #updating }
ExternalUnixOSProcess >> update: aParameter [ 

	| accessible |
	aParameter == #runState
		ifTrue: [| statusArray | 
			"Has the process exited?"
			statusArray := self accessor primGetChildExitStatus: self pid.
			statusArray notNil
				ifTrue: [self exitStatus: (statusArray at: 2).
						^ self complete]].
	aParameter == #accessibility
		ifTrue: ["Does the process still exist, and is it reachable?"
			((accessible := self isAccessible) notNil and: [accessible])
				ifFalse: [^ self isRunning ifTrue: [self unknownRunState]]].
	super update: aParameter

]

{ #category : #evaluating }
ExternalUnixOSProcess >> value [
	"Start the external process"

	self isNotYetRunning ifTrue: [self forkChild; closeStreams]

]
