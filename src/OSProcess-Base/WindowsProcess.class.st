"
I represent a Windows operating system process, such as the process in which the Squeak VM is currently running. I collaborate with an instance of WindowsOSProcessAccessor to provide primitive access to the external operating system. My instance variables are maintained as a convenience to allow inspection of an OSProcess. Access to these variables should always be done with my accessor methods, which update the instance variables by querying my WindowsOSProcessAccessor.

My process ID and process handle (a Win32 HANDLE) are held by my pid and processHandle variables. The main thread for this process is held by my mainThread variable.

Standard input, output, and error streams are available, and my be used when the console is open (WindowsProcess>>openConsole). They can also be reassigned to file streams (WindowsOSProcessAccessor>>setStdOut:).

When external processes are created, they are added to my allMyChildren collection, and a thread is created to wait for any of them to exit. This thread is held by my childWatcherThread instance variable while the thread is active, and is also added to my threads collection.

Whenever a child process exits, the childWatcherThread will signal a Semaphore (a Smalltalk Semaphore, not a Windows semaphore), then exit. A Squeak process in my processAccessor waits on this Semaphore, and sends an 'update: #childProcessStatus' message to me. In response to this, I update the status of my active child processes, one or more of which will have exited. If any of my child processes are still active, I set a new childWatcherThread to wait for them to exit.

Note that some Windows applications will exit their main process after creating another application process. These applications will appear to Squeak as if they have exited immediately, even though the application is running.
"
Class {
	#name : #WindowsProcess,
	#superclass : #ThisOSProcess,
	#instVars : [
		'processHandle',
		'environment',
		'mainThread',
		'threads'
	],
	#category : #'OSProcess-Win32'
}

{ #category : #'platform identification' }
WindowsProcess class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for
	the Squeak VM running on the current platform."

	^ self isWindows

]

{ #category : #'child process management' }
WindowsProcess >> activeHandles [
	"Answer an Array of handles for all children that are believed to be running."

	^ (self activeChildren collect: [:c | c handle]) asArray

]

{ #category : #'child process management' }
WindowsProcess >> allMyChildren [
	"On Windows, the process ID is not unique. Use an OrderedCollection instead
	of a Dictionary to keep track of the child processes."

	allMyChildren ifNil: [ allMyChildren _ OrderedCollection new ].
	^ allMyChildren
]

{ #category : #console }
WindowsProcess >> closeConsole [
	"Close the console. The standard input, output and error streams will no longer be available."

	"OSProcess thisOSProcess closeConsole"

	self processAccessor primFreeConsole.
	self refreshFromProcessAccessor

]

{ #category : #'child process creation' }
WindowsProcess >> command: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in
	the standard C library, except that aCommandString runs asynchronously
	in a child process. Answer an instance of ExternalWindowsProcess which
	is a proxy for the new Windows process."

	"OSProcess command: 'SOL'"

	^ ExternalWindowsOSProcess command: aCommandString

]

{ #category : #accessing }
WindowsProcess >> environment [

	^ environment

]

{ #category : #'child process creation' }
WindowsProcess >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [
	"Use my processAccessor to call vfork() and execve() and create a
	new child task. Answer a proxy for the new task, an instance of
	ExternalWindowsProcess."

	self notYetImplemented

]

{ #category : #environment }
WindowsProcess >> getCwd [
	"Get current working directory. If this cannot be obtained from the
	environment, answer a reasonable default."

	"OSProcess thisOSProcess getCwd"

	^ self processAccessor primGetCurrentWorkingDirectory
		ifNil: [FileDirectory default pathName]



]

{ #category : #private }
WindowsProcess >> getEnvironmentDictionary [
	"Answer an environment dictionary using an OSProcessAccessor."

	"OSProcess thisOSProcess getEnvironmentDictionary"

	| strings env |
	strings _ processAccessor primGetEnvironmentStrings.
	strings isNil
		ifTrue:
			[^ nil]
		ifFalse:
			[env _ Dictionary new.
			strings do: [:s |
				env at: (s copyUpTo: $=) asSymbol put: (s copyAfterLast: $=)].
			^ env]

]

{ #category : #'initialize - release' }
WindowsProcess >> initialize [
	"Set my instance variables to reflect the state of the OS process in which 
	this Smalltalk virtual machine is executing. On Windows, we cannot rely
	on the pid to have changed when the VM is restarted, so use a one-shot
	function to determine if we are restarting the VM (as opposed to returning
	from an image save)."

	processAccessor ifNotNil:
		[processAccessor removeDependent: self.
		processAccessor _ nil].
	(self processAccessor canAccessSystem not or: [processAccessor primOneShot]) ifTrue:
		["Restarting the VM in a new process"
		self resetChildProcessDictionary.
		self resetThreads.
		self threads; mainThread.
		processHandle _ nil.
		self processHandle].
	self refreshFromProcessAccessor

]

{ #category : #'platform identification' }
WindowsProcess >> isResponsibleForThisPlatform [
	"Answer true is this is an instance of the class which is responsible for representing
	the OS process for the Squeak VM running on the current platform. A false answer is
	usually the result of running the image on a different platform and VM."

	^ self class isWindows

]

{ #category : #accessing }
WindowsProcess >> mainThread [
	"The main thread for this OS process. The handle for this thread is a
	pseudo-handle, and cannot be used to close the main thread."

	^ mainThread ifNil: [mainThread _ processAccessor getMainThread]
]

{ #category : #console }
WindowsProcess >> openConsole [
	"Open a console. This makes the standard input, output and error streams available."

	"OSProcess thisOSProcess openConsole"

	self processAccessor primAllocConsole.
	self refreshFromProcessAccessor

]

{ #category : #environment }
WindowsProcess >> path [
	"Newer versions of Windows mixed case"

	^ self environment
		at: #PATH
		ifAbsent: [environment
				at: #Path
				ifAbsent: ['']]
]

{ #category : #accessing }
WindowsProcess >> pid [

	^ pid _ self processAccessor primGetPid

]

{ #category : #accessing }
WindowsProcess >> processHandle [
	"The handle for this OS process. This is a pseudo-handle, a constant provided
	by Windows to represent the process. Note that the main thread handle is also
	represented by a pseudo-handle."

	^ processHandle ifNil: [processHandle _ self processAccessor primGetPidHandle]

]

{ #category : #updating }
WindowsProcess >> refreshFromProcessAccessor [
	"Set my instance variables to reflect the state of the OS process in which this Smalltalk
	virtual machine is executing."

	sessionID _ self processAccessor getSessionIdentifier.
	pid _ processAccessor primGetPid.
	self setStdIn.
	self setStdOut.
	self setStdErr.
	environment _ self getEnvironmentDictionary

]

{ #category : #'child process management' }
WindowsProcess >> registerChildProcess: anOSProcess [
	"Register the external process and set an exit handler thread to signal when
	the process exits."

	self allMyChildren add: anOSProcess.
	self threads add: self restartChildWatcherThread.
	^ anOSProcess

]

{ #category : #'initialize - release' }
WindowsProcess >> resetThreads [
	"If any cleanup is required, do it here."

	threads _ nil.
	mainThread _ nil

]

{ #category : #'child process management' }
WindowsProcess >> restartChildWatcherThread [
	"Set an exit handler thread to signal when the process exits."


	^ self processAccessor restartChildWatcherThread: self activeHandles

]

{ #category : #private }
WindowsProcess >> setStdErr [
	"Reset to nil if the console has been closed"

	^ self processAccessor getStdErr isNil
		ifTrue: [stdErr _ nil]
		ifFalse: [super setStdErr]

]

{ #category : #private }
WindowsProcess >> setStdIn [
	"Reset to nil if the console has been closed"

	^ self processAccessor getStdIn isNil
		ifTrue: [stdIn _ nil]
		ifFalse: [super setStdIn]

]

{ #category : #private }
WindowsProcess >> setStdOut [
	"Reset to nil if the console has been closed"

	^ self processAccessor getStdOut isNil
		ifTrue: [stdOut _ nil]
		ifFalse: [super setStdOut]

]

{ #category : #accessing }
WindowsProcess >> threads [
	"One or more threads of execution within the OS process. The main
	thread for the process is held by the mainThread variable and is not
	included in this collection. Threads are created to wait for the exit of
	child processes, so this collection grows as child processes are created."

	^ threads ifNil: [threads _ OrderedCollection new]

]

{ #category : #'child process management' }
WindowsProcess >> unregisterChildProcess: anOSProcess [

	^ self allMyChildren remove: anOSProcess pid

]

{ #category : #updating }
WindowsProcess >> update: aParameter [
	"Framework to update some or all of the instance variables based on external events,
	such as receipt of a sigchd signal when a child process exits."

	(aParameter == (self processAccessor)) ifTrue:
		[^ self refreshFromProcessAccessor; yourself].
	(aParameter == #pid) ifTrue:
		[^ self resetChildProcessDictionary. "Forget children of prior process"].
	(aParameter == #childProcessStatus) ifTrue:
		[^ self updateActiveChildren; changed; yourself].
	(aParameter == #startUp) ifTrue:
		[^ self update: #pid].
	aParameter == #invalidProcessAccessor ifTrue:
		[processAccessor _ processAccessor ifNotNil: [processAccessor removeDependent: self. nil].
		^ self].
	self error: 'Unexpected update parameter'
]

{ #category : #'child process management' }
WindowsProcess >> updateActiveChildren [

	super updateActiveChildren.
	self restartChildWatcherThread

]
