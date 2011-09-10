"
I represent the operating system process in which the Squeak VM is currently running. My subclasses implement system specific features for Unix, Windows, MacOS, or other operating systems by collaborating with corresponding subclasses of OSProcessAccessor to provide primitive access to the external operating system.

"
Class {
	#name : #ThisOSProcess,
	#superclass : #OSProcess,
	#instVars : [
		'sessionID',
		'stdIn',
		'stdOut',
		'stdErr',
		'processAccessor',
		'allMyChildren',
		'accessProtect'
	],
	#classVars : [
		'ThisInstance'
	],
	#category : #'OSProcess-Base'
}

{ #category : #'concrete subclasses' }
ThisOSProcess class >> concreteClass [

	"ThisOSProcess concreteClass"

	^ self subclasses
		detect: [:c | c isResponsibleForThisPlatform]
		ifNone: [self notify: self printString,
					': No concrete class implementation available for system type ',
					self platformName printString.
				nil]


]

{ #category : #'concrete subclasses' }
ThisOSProcess class >> concreteClassOrNil [

	"ThisOSProcess concreteClassOrNil"

	^ self subclasses
		detect: [:c | c isResponsibleForThisPlatform]
		ifNone: [nil]


]

{ #category : #'initialize-release' }
ThisOSProcess class >> initialize [

	"ThisOSProcess initialize"

	OSProcess initialize. "required to ensure the change sets file in smoothly"
	AttachableFileStream initialize.
	OSProcessAccessor initialize.
	self initializeThisOSProcess.
	Smalltalk addToStartUpList: ThisOSProcess.
	Smalltalk addToShutDownList: ThisOSProcess

]

{ #category : #'initialize-release' }
ThisOSProcess class >> initializeThisOSProcess [
	"Initialize the singleton instance, creating a new instance only if the
	platform type has changed since shutdown (running on a different
	type of computer)."

	(ThisInstance isNil or: [ThisInstance isResponsibleForThisPlatform not])
		ifTrue: [ | cls |
			(cls := self concreteClassOrNil)
				ifNil: [ThisInstance := nil "no concrete class for this platform"]
				ifNotNil: [ThisInstance := cls basicNew]].
	ThisInstance initialize
]

{ #category : #'initialize-release' }
ThisOSProcess class >> initializeThisOSProcessWithNotifier [
	"Initialize the singleton instance, creating a new instance only if the
	platform type has changed since shutdown (running on a different
	type of computer). Warn if no implementation is available for this platform."

	(ThisInstance isNil or: [ThisInstance isResponsibleForThisPlatform not])
		ifTrue: [ThisInstance := self concreteClass basicNew].
	ThisInstance initialize
]

{ #category : #'instance creation' }
ThisOSProcess class >> new [

	self notify: self name, ': Only one instance of ThisOSProcess or any of its subclasses should exist in the image. Use #thisOSProcess to obtain the singleton instance.'.
	self shouldNotImplement
]

{ #category : #'system startup' }
ThisOSProcess class >> shutDown: quitting [
	"Break dependency on my OSProcessAccessor. This is done explicitly at
	shutDown time in order to prevent possible problems when an image is
	restarted on another platform type, in which case a new ThisOSProcess
	instance is created and the old instance could still have an unwanted
	dependency on an OSProcessAccessor."

	quitting ifTrue: [OSProcess accessor breakDependents]

]

{ #category : #'system startup' }
ThisOSProcess class >> startUp: resuming [
	"Initialize my singleton instance, and the singleton instance of my
	OSProcessAccessor. On Unix, set the signal handler in my process
	accessor to respond to externally generated sigchld signals. This
	must be done after each image restart in order to call a primitive
	which informs the VM of the identity of the semaphore to signal.
	When not running on a Unix system, the primitive fails and the
	method has no effect. Notify dependents of the singleton instance
	if the image has restarted in a different OS process (this is not the
	case when #startUp is called after a simple image save). The
	notification is done in the initialization of my OSProcessAccessor."

	| aio |
	(aio := Smalltalk at: #AioEventHandler)
		ifNotNil: [ aio startUp: resuming ].
	self initializeThisOSProcess
]

{ #category : #'instance creation' }
ThisOSProcess class >> thisOSProcess [
	"Answer a single instance of the class corresponding to the OS process in 
	which this Smalltalk image is executing."

	"ThisOSProcess thisOSProcess"

	^ ThisInstance
]

{ #category : #comparing }
ThisOSProcess >> = processProxy [
	"True if this is a proxy that represents the same OS process as processProxy"

	^ ((self isKindOf: ThisOSProcess)
			and: [pid = processProxy pid])
		and: [sessionID = processProxy sessionID]
]

{ #category : #'child process management' }
ThisOSProcess >> activeChildren [
	"Answer child processes which are currently believed to be running."

	"OSProcess thisOSProcess activeChildren"

	| children |
	accessProtect
		critical: [ children := allMyChildren select: [ :p | p isRunning ] ].
	^children

]

{ #category : #'child process management' }
ThisOSProcess >> allMyChildren [

	^ allMyChildren
]

{ #category : #'display management' }
ThisOSProcess >> canConnectToXDisplay: xDisplayName [
	"Open and close a connection to displayName. It the connection was successfully
	opened, answer true; otherwise false. This is intended to check for the ability
	to open an X display prior to actually making the attempt."

	"self thisOSProcess canConnectToXDisplay: ':0.0' "
	"self thisOSProcess canConnectToXDisplay: ':1' "
	"self thisOSProcess canConnectToXDisplay: 'bogus:0' " "<-make sure network is running first!"

	(xDisplayName isKindOf: String) ifFalse: [^ false].
	^ self processAccessor primCanConnectToXDisplay: xDisplayName

]

{ #category : #'child process management' }
ThisOSProcess >> childPids [

	^ allMyChildren asArray asArray collect: [ :p | p pid ]

]

{ #category : #'display management' }
ThisOSProcess >> closeXDisplay [
	"Become headless by closing the X session. All subsequent processing should involve
	no further display interaction."

	"self thisOSProcess closeXDisplay"

	| proc |
	proc := self processAccessor primKillDisplay.
	proc ifNil: [self noAccessorAvailable].
	^ proc

]

{ #category : #'child process creation' }
ThisOSProcess >> command: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in
	the standard C library, except that aCommandString runs asynchronously
	in a child process. Answer an instance of ExternalMacOSProcess which
	is a proxy for the new OS process."

	self subclassResponsibility
]

{ #category : #'display management' }
ThisOSProcess >> currentXDisplayName [

	"self thisOSProcess currentXDisplayName"

	^ self processAccessor primGetXDisplayName
]

{ #category : #'display management' }
ThisOSProcess >> decapitate [
	"Become headless by closing the X session. All subsequent processing should involve
	no further display interaction."

	"self thisOSProcess decapitate"

	^ self closeXDisplay

]

{ #category : #'child process management' }
ThisOSProcess >> discardExitedChildren [
	"Remove entries for completed child processed from dictionary."

	self updateAllMyChildren.
	accessProtect
		critical: [ allMyChildren := allMyChildren select: [ :p | p isComplete not ] ].
	^ allMyChildren

]

{ #category : #'display management' }
ThisOSProcess >> disconnectXDisplay [
	"Disconnect from the X server, but do not close the existing Squeak window. A new
	display medium must be opened before further interaction with the display."

	"self thisOSProcess disconnectXDisplay"

	| proc |
	proc := self processAccessor primDisconnectDisplay.
	proc ifNil: [self noAccessorAvailable].
	^ proc

]

{ #category : #'display management' }
ThisOSProcess >> displayOnXServer: xDisplayName [
	"Check if it is possible to open a display on the X server identified by
	xDisplayName. If so, close the current X display and reopen it on
	the new server. On success, answer the previous display name. On
	failure, answer a string with an error message. This method is expected
	to be called by a web server or other application which may wish to
	make use of the result string."

	"self thisOSProcess displayOnXServer: ':0.0' "
	"self thisOSProcess displayOnXServer: 'unix:0' "
	"self thisOSProcess displayOnXServer: ':1' "
	"self thisOSProcess displayOnXServer: 'noSuchMachine'"
	"self thisOSProcess displayOnXServer: 'noSuchMachine:0'" "<-make sure network is running first!"

	| previousDisplayName |
	(xDisplayName isKindOf: String)
		ifFalse: [^ 'expected display name string'].
	previousDisplayName := self currentXDisplayName.
	(self canConnectToXDisplay: xDisplayName)
		ifTrue:
			[self decapitate.
			self setXDisplayName: xDisplayName.
			self recapitate.
			^ previousDisplayName]
		ifFalse:
			[^ 'cannot connect to display ', xDisplayName]

]

{ #category : #'child process management' }
ThisOSProcess >> exitedChildren [
	"Answer child processes which have exited and are no longer running."

	"OSProcess thisOSProcess exitedChildren"

	| children |
	accessProtect
		critical: [ children := allMyChildren select: [ :p | p isComplete ]].
	^ children

]

{ #category : #finalization }
ThisOSProcess >> finalize [

	processAccessor
		ifNotNil: 
			[processAccessor removeDependent: self.
			processAccessor finalize].
	processAccessor := nil
]

{ #category : #'display management' }
ThisOSProcess >> flushXDisplay [
	"Synchronize output to the X display."

	"self thisOSProcess flushXDisplay"

	^ self processAccessor primFlushXDisplay


]

{ #category : #'child process creation' }
ThisOSProcess >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [
	"Use my processAccessor to call vfork() and execve() and create a
	new child task. Answer a proxy for the new task, an instance of
	ExternalOSProcess."

	self subclassResponsibility
]

{ #category : #environment }
ThisOSProcess >> getCwd [

	self subclassResponsibility
]

{ #category : #'private - IOHandle' }
ThisOSProcess >> handleFromAccessor: aByteArrayOrIOAccessor [

	UseIOHandle
		ifTrue: [aByteArrayOrIOAccessor isNil
			ifTrue: [^ nil]
			ifFalse: [^ aByteArrayOrIOAccessor asSQFileStruct]]
		ifFalse: [^ aByteArrayOrIOAccessor]

]

{ #category : #'private - IOHandle' }
ThisOSProcess >> handleFromFileStream: aFileStream [

	UseIOHandle
		ifTrue: [^ aFileStream ioHandle asSQFileStruct]
		ifFalse: [^ aFileStream fileID]

]

{ #category : #comparing }
ThisOSProcess >> hash [

	^ (pid ifNil: [self identityHash])
		+ (sessionID
				ifNil: [0]
				ifNotNil: [sessionID sum])
]

{ #category : #'initialize - release' }
ThisOSProcess >> initialize [
	"Set my instance variables to reflect the state of the OS process in which 
	this Smalltalk virtual machine is. executing."

	accessProtect := Semaphore forMutualExclusion.
	self initializeAllMyChildren.
	processAccessor ifNotNil:
		[processAccessor breakDependents.
		processAccessor := nil].
	((self processAccessor notNil
		and: [processAccessor canAccessSystem])
			and: [pid ~= processAccessor primGetPid])
		ifTrue: [self resetChildProcessDictionary]

]

{ #category : #'initialize - release' }
ThisOSProcess >> initializeAllMyChildren [
	"Use a Dictionary if process identifiers are unique. On Windows, the
	process ID is not unique, so use an OrderedCollection instead."

	self subclassResponsibility

]

{ #category : #'display management' }
ThisOSProcess >> isConnectedToXServer [
	"Answer true if VM is currently connected to an X server."

	"self thisOSProcess isConnectedToXServer"

	^ self processAccessor primIsConnectedToXServer


]

{ #category : #'platform identification' }
ThisOSProcess >> isResponsibleForThisPlatform [
	"Answer true is this is an instance of the class which is responsible for representing
	the OS process for the Squeak VM running on the current platform. A false answer is
	usually the result of running the image on a different platform and VM."

	^ self subclassResponsibility
]

{ #category : #'private - IOHandle' }
ThisOSProcess >> isStdErr: anIOHandle [
	"Answer true if anIOHandle represents stderr."

	| realHandle |
	anIOHandle ifNil: [^ false].
	realHandle := self processAccessor getStdErrHandle.
	realHandle ifNil: [^ false].
	UseIOHandle
		ifTrue: [^ anIOHandle handle = realHandle handle]
		ifFalse: [ | len | "compare first two fields of SQFile struct"
			len := self processAccessor sizeOfInt + self processAccessor sizeOfPointer.
			^ (anIOHandle first: len) = (realHandle first: len)]

]

{ #category : #'private - IOHandle' }
ThisOSProcess >> isStdIn: anIOHandle [
	"Answer true if anIOHandle represents stdin."

	| realHandle |
	anIOHandle ifNil: [^ false].
	realHandle := self processAccessor getStdInHandle.
	realHandle ifNil: [^ false].
	UseIOHandle
		ifTrue: [^ anIOHandle handle = realHandle handle]
		ifFalse: [ | len | "compare first two fields of SQFile struct"
			len := self processAccessor sizeOfInt + self processAccessor sizeOfPointer.
			^ (anIOHandle first: len) = (realHandle first: len)]

]

{ #category : #'private - IOHandle' }
ThisOSProcess >> isStdOut: anIOHandle [
	"Answer true if anIOHandle represents stdout."

	| realHandle |
	anIOHandle ifNil: [^ false].
	realHandle := self processAccessor getStdOutHandle.
	realHandle ifNil: [^ false].
	UseIOHandle
		ifTrue: [^ anIOHandle handle = realHandle handle]
		ifFalse: [ | len | "compare first two fields of SQFile struct"
			len := self processAccessor sizeOfInt + self processAccessor sizeOfPointer.
			^ (anIOHandle first: len) = (realHandle first: len)]

]

{ #category : #updating }
ThisOSProcess >> needsRefresh [
	"Answer true if the sessionID variable is out of date with respect to the running
	OS Process. Subclasses should provide implementation, answer true as default."

	^ true
]

{ #category : #'display management' }
ThisOSProcess >> openXDisplay [
	"Restore headful display opening the X session."

	"self thisOSProcess closeXDisplay. (Delay forSeconds: 5) wait. self thisOSProcess openXDisplay."

	| proc |
	proc := self processAccessor primOpenXDisplay.
	proc ifNil: [self noAccessorAvailable].
	^ proc

]

{ #category : #accessing }
ThisOSProcess >> processAccessor [

	| a |
	processAccessor
		ifNil: 
			[a := OSProcessAccessor forThisOSProcess.
			a isResponsibleForThisPlatform ifTrue:
				[processAccessor := a.
				processAccessor addDependent: self]].
	^ processAccessor
]

{ #category : #'display management' }
ThisOSProcess >> recapitate [
	"Restore headful display opening the X session."

	"self thisOSProcess decapitate. (Delay forSeconds: 5) wait. self thisOSProcess recapitate."

	^ self openXDisplay

]

{ #category : #updating }
ThisOSProcess >> refreshFromProcessAccessor [
	"Set my instance variables to reflect the state of the OS process in which this Smalltalk
	virtual machine is executing."

	self subclassResponsibility
]

{ #category : #'child process management' }
ThisOSProcess >> registerChildProcess: anOSProcess [

	self subclassResponsibility
]

{ #category : #updating }
ThisOSProcess >> resetChildProcessDictionary [
	"Forget all the entries in the allMyChildren dictionary. This method may be called
	when a new session is started, since the child processes of the previous session are
	probably no longer of any interest."

	self updateAllMyChildren. "Ensure contents are up to date before releasing them."
	self initializeAllMyChildren

]

{ #category : #accessing }
ThisOSProcess >> sessionID [

	^ sessionID
]

{ #category : #private }
ThisOSProcess >> setStdErr [
	"If stdErr is nil, then set it. If not nil, check to see if it is has a valid connection to
	stderr. If not valid, then replace it, otherwise answer the existing valid stream.
	Obscure bug warning: If a valid AttachableFileStream on stderr is garbage collected,
	then stderr will be closed. It is advisable (but not necessary) to treat the stream
	on stderr as a singleton, but in any case, any extra instances attached to stderr
	should not be allowed to be garbage collected."

	| stdErrHandle |
	stdErr ifNotNil:
			[(self isStdErr: stdErr ioHandle) ifTrue: [^ stdErr]].
	stdErrHandle := self processAccessor getStdErrHandle.
	stdErrHandle ifNotNil:
			[stdErr := AttachableFileStream name: 'stderr' attachTo: stdErrHandle writable: true].
	^ stdErr

]

{ #category : #private }
ThisOSProcess >> setStdIn [
	"If stdIn is nil, then set it. If not nil, check to see if it is has a valid connection to
	stdin. If not valid, then replace it, otherwise answer the existing valid stream.
	Obscure bug warning: If a valid AttachableFileStream on stdin is garbage collected,
	then stdin will be closed. It is advisable (but not necessary) to treat the stream
	on stdin as a singleton, but in any case, any extra instances attached to stdin
	should not be allowed to be garbage collected."

	| stdInHandle |
	stdIn ifNotNil:
			[(self isStdIn: stdIn ioHandle) ifTrue: [^ stdIn]].
	stdInHandle := self processAccessor getStdInHandle.
	stdInHandle ifNotNil:
			[stdIn := AttachableFileStream name: 'stdin' attachTo: stdInHandle writable: false].
	^ stdIn


]

{ #category : #private }
ThisOSProcess >> setStdOut [
	"If stdOut is nil, then set it. If not nil, check to see if it is has a valid connection to
	stdout. If not valid, then replace it, otherwise answer the existing valid stream.
	Obscure bug warning: If a valid AttachableFileStream on stdout is garbage collected,
	then stdout will be closed. It is advisable (but not necessary) to treat the stream
	on stdout as a singleton, but in any case, any extra instances attached to stdout
	should not be allowed to be garbage collected."

	| stdOutHandle |
	stdOut ifNotNil:
			[(self isStdOut: stdOut ioHandle) ifTrue: [^ stdOut]].
	stdOutHandle := self processAccessor getStdOutHandle.
	stdOutHandle ifNotNil:
			[stdOut := AttachableFileStream name: 'stdout' attachTo: stdOutHandle writable: true].
	^ stdOut

]

{ #category : #'display management' }
ThisOSProcess >> setXDisplayName: xDisplayName [
	"Set X display name for use by the next call to recapitate"

	"self thisOSProcess setXDisplayName: 'unix:0' "
	"self thisOSProcess setXDisplayName: ':1' "

	self processAccessor primSetXDisplayName: xDisplayName


]

{ #category : #accessing }
ThisOSProcess >> stdErr [

	^ stdErr
]

{ #category : #accessing }
ThisOSProcess >> stdIn [

	^ stdIn
]

{ #category : #accessing }
ThisOSProcess >> stdOut [

	^ stdOut
]

{ #category : #'child process management' }
ThisOSProcess >> unregisterChildProcess: anOSProcess [

	self subclassResponsibility

]

{ #category : #updating }
ThisOSProcess >> update: aParameter [

	aParameter == #invalidProcessAccessor ifTrue: [processAccessor := nil].
	^ super update: aParameter
]

{ #category : #'child process management' }
ThisOSProcess >> updateActiveChildren [
	"Test each active child for its completion status and update runState and exitStatus
	accordingly. This method may be called when a semaphore is set indicating that
	some child OSProcess has died. A better approach might be to use an event queue
	for death of child events; however, until event queues are part of Squeak image,
	this polling mechanism is sufficient."

	self activeChildren do:
		[:child | child update: #runState]

]

{ #category : #'child process management' }
ThisOSProcess >> updateAllMyChildren [
	"Test each child to make sure that it is still accessible. If the child is believed to be
	running, check to see if it has exited, and update runState and exitStatus accordingly."

	| children |
	accessProtect critical: [children := allMyChildren asArray].
	children do:
		[:child |
		child update: #accessibility.
		child isRunning ifTrue: [child update: #runState]]

]
