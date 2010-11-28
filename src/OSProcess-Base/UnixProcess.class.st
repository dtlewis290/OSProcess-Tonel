"
I represent the Unix operating system process in which this Squeak session is running. I collaborate with an instance of UnixOSProcessAccessor to provide access to the external operating system. My instance variables are updated when my process accessor changes, allowing them to be monitored with a Smalltalk inspector.

"
Class {
	#name : #UnixProcess,
	#superclass : #ThisOSProcess,
	#instVars : [
		'ppid',
		'pthread',
		'path',
		'programName',
		'arguments',
		'environment'
	],
	#category : #'OSProcess-Unix'
}

{ #category : #utility }
UnixProcess class >> arguments [

	"UnixProcess arguments"

	^ self thisOSProcess arguments

]

{ #category : #examples }
UnixProcess class >> backgroundProcessInHeadlessSqueak [
	"Demonstrate running a ''batch job'' in a low priority background Squeak,
	with output written to an OSPipe. This Squeak image reads data from the
	pipe and displays it on the Transcript. The background Squeak will write
	enough data to block an OSPipe, so the foreground Squeak loops while
	reading available data up to end of file.

	Open a Transcript, then '' inspect it '' on this method. Process runs
	indefinitely, so terminate the process to end demo."

	"UnixProcess backgroundProcessInHeadlessSqueak"

	^ [[| pipe backgroundJob ws s | 
	pipe := OSPipe new.
	backgroundJob := OSProcess thisOSProcess
	forkHeadlessSqueakAndDoThenQuit: [| beers | 
		OSProcess accessor nice: 1. "lower priority of background OS process"
		beers := [:i | (i < 1 ifTrue: ['no more'] ifFalse: [i asString])
					, ' bottle' , (i = 1 ifTrue: [''] ifFalse: ['s'])].
		(99 to: 1 by: -1) do: [:count | pipe nextPutAll:
			(beers value: count) , ' of beer on the wall, '
			, (beers value: count) , ' of beer' , String cr
			, 'take one down and pass it around, '
			, (beers value: count - 1) , ' of beer on the wall'; cr].
		pipe close].
	WorldState addDeferredUIMessage:
		[Transcript show: backgroundJob asString , ' started'; cr].
	pipe closeWriter. "don't need writer end, close it before the #upToEnd"
	"pipe writer blocks when pipe full, so we need to loop while reading to end "
	ws := WriteStream on: ''.
	[backgroundJob isComplete] whileFalse:
		[(Delay forMilliseconds: 200) wait.
		(s := pipe upToEnd) ifNotNil: [ws nextPutAll: s]].
	pipe close.
	WorldState addDeferredUIMessage:
		[Transcript show: backgroundJob asString
			, ' completed, display results in 2 seconds'; cr].
	(Delay forSeconds: 2) wait.
	WorldState addDeferredUIMessage:
		[Transcript show: ws contents.
		Transcript cr; show: 'delay 5 seconds before forking next Squeak job'; cr].
	(Delay forSeconds: 5) wait] repeat]
		forkAt: Processor userBackgroundPriority
]

{ #category : #'X display - deprecated' }
UnixProcess class >> canConnectToXDisplay: xDisplayName [
	"Deprecated. See ThisOSProcess>canConnectToXDisplay:"

	"self canConnectToXDisplay: ':0.0' "

	^ self thisOSProcess canConnectToXDisplay: xDisplayName

]

{ #category : #examples }
UnixProcess class >> catAFile [
	"Copy contents of a file to standard output. This demonstrates reassigning stdin to an open FileStream."

	"UnixProcess catAFile"

	| in proc |
	in := FileStream readOnlyFileNamed: '/etc/hosts'.
	proc := self forkJob: '/bin/cat'
			arguments: nil
			environment: nil
			descriptors: (Array with: in with: nil with: nil).
	in close.
	proc ifNil: [self noAccessorAvailable].
	^ proc
]

{ #category : #examples }
UnixProcess class >> catFromFileToFiles [
	"Copy contents of a file to another file, with any error messages going 
	to a third file."

	"UnixProcess catFromFileToFiles"

	| in out err proc |
	in := FileStream readOnlyFileNamed: '/etc/hosts'.
	out := FileStream newFileNamed: '/tmp/deleteMe.out'.
	err := FileStream newFileNamed: '/tmp/deleteMe.err'.
	proc := UnixProcess
				forkJob: '/bin/cat'
				arguments: nil
				environment: nil
				descriptors: (Array
						with: in
						with: out
						with: err).
	in close.
	out close.
	err close.
	proc ifNil: [self noAccessorAvailable].
	^ proc
]

{ #category : #examples }
UnixProcess class >> clientServerDemo [
	"Start a new headless instance of Squeak running in a child OS process. The new
	instance is a nearly identical copy of its parent, resuming execution at the same
	point as the parent. The child process will run a TCP server process in the headless
	image, then exit. Test results are written to the Transcript.

	Answer '127 0 0 1' in response to the host address dialog."

	"UnixProcess clientServerDemo"

	| proc |
	proc := self forkHeadlessSqueakAndDoThenQuit: [Socket remoteTestServerTCP].
	proc ifNotNil: [Socket remoteTestClientTCP].
	^ proc


]

{ #category : #examples }
UnixProcess class >> clientServerDemo2 [
	"Start a new instance of Squeak running in a child OS process. The new 
	instance is a nearly identical copy of its parent, resuming execution at
	the same point as the parent. The child process will run a TCP server
	process, then exit. Test results are written to the Transcript. "

	"UnixProcess clientServerDemo2"

	| remotePort remoteHost serverBlock socket buffer n bytesToSend sendBuf
	receiveBuf done bytesSent bytesReceived packetsSent packetsReceived t |

	remotePort := 54321.
	remoteHost := 'localhost'.
	serverBlock := 
			[Transcript clear; cr; show: 'This is the server Squeak session'; cr.
			Socket initializeNetworkIfFail: [^ nil].
			socket := Socket newTCP.
			socket listenOn: remotePort.
			buffer := String new: 4000.
			socket waitForConnectionUntil: Socket standardDeadline.
			[socket isConnected]
				whileTrue: [socket dataAvailable
						ifTrue: 
							[n := socket receiveDataInto: buffer.
							socket sendData: buffer count: n]].
			socket closeAndDestroy].

	(UnixProcess forkSqueakAndDoThenQuit: serverBlock)
		ifNil: [self noAccessorAvailable. ^ nil].
	Transcript cr; show: 'This is the client Squeak session'; cr.
	Transcript show: 'starting client/server TCP test'; cr.
	Transcript show: 'initializing network ... '.
	Socket initializeNetworkIfFail: [^ Transcript show: 'failed'].
	Transcript show: 'ok'; cr.
	socket := Socket newTCP.
	socket connectTo: (NetNameResolver addressForName: remoteHost) port: remotePort.
	socket waitForConnectionUntil: Socket standardDeadline.
	Transcript show: 'client endpoint created'; cr.
	bytesToSend := 1000000.
	sendBuf := String new: 4000 withAll: $x.
	receiveBuf := String new: 50000.
	done := false.
	bytesSent := bytesReceived := packetsSent := packetsReceived := 0.
	t := Time
				millisecondsToRun: 
					[[done]
						whileFalse: 
							[(socket sendDone and: [bytesSent < bytesToSend])
								ifTrue: 
									[packetsSent := packetsSent + 1.
									bytesSent := bytesSent + (socket sendData: sendBuf)].
							socket dataAvailable
								ifTrue: 
									[packetsReceived := packetsReceived + 1.
									bytesReceived := bytesReceived + (socket receiveDataInto: receiveBuf)].
							done := bytesSent >= bytesToSend].
					[bytesReceived < bytesToSend]
						whileTrue: [socket dataAvailable
								ifTrue: 
									[packetsReceived := packetsReceived + 1.
									bytesReceived := bytesReceived + (socket receiveDataInto: receiveBuf)]]].
	socket closeAndDestroy.
	Transcript show: 'remoteClient TCP test done; time = ' , t printString; cr.
	Transcript show: packetsSent printString , ' packets, ' , bytesSent printString ,
		' bytes sent (' , (bytesSent * 1000 // t) printString , ' bytes/sec)'; cr.
	Transcript show: packetsReceived printString , ' packets, ' , bytesReceived printString ,
		' bytes received (' , (bytesReceived * 1000 // t) printString , ' bytes/sec)'; cr.
	^ bytesReceived
]

{ #category : #examples }
UnixProcess class >> cloneSqueak [
	"Start a new instance of Squeak running in a child OS process. The new instance is a
	nearly identical copy of its parent, resuming execution at the same point as the
	parent, and differentiated only by the return value of this method."

	"UnixProcess cloneSqueak"

	| proc |
	proc := self forkSqueak.
	proc ifNil: [self noAccessorAvailable].
	^ proc

]

{ #category : #'X display - deprecated' }
UnixProcess class >> currentXDisplayName [
	"Deprecated. See ThisOSProcess>>currentXDisplayName"

	"self currentXDisplayName"

	^ self thisOSProcess currentXDisplayName

]

{ #category : #'X display - deprecated' }
UnixProcess class >> decapitate [
	"Deprecated. See ThisOSProcess>>decapitate"

	"self decapitate"

	^ OSProcess thisOSProcess decapitate
]

{ #category : #'X display - deprecated' }
UnixProcess class >> displayOnXServer: xDisplayName [
	"Deprecated. See ThisOSProcess>>displayOnXServer"

	"self displayOnXServer: ':0.0' "
	"self displayOnXServer: 'unix:0' "
	"self displayOnXServer: ':1' "
	"self displayOnXServer: 'noSuchMachine'"
	"self displayOnXServer: 'noSuchMachine:0'" "<-make sure network is running first!"

	^ OSProcess thisOSProcess displayOnXServer: xDisplayName
]

{ #category : #examples }
UnixProcess class >> eightLeafSqueakTree [
	"Clone this squeak three times, resulting in a total of (2 raisedTo: 3) nearly identical
	squeaks. Have a look at the pidArray inspectors and to the debug messages on stdout
	in order to see what is going on. The tree of processes looks like this:

	111
	 +--------+--------+
	 |		 |		 |
	011		101		110
	 +---+	 |
	 |	 |	100
	010	001
		 |
		000
	"

	"UnixProcess eightLeafSqueakTree inspect"

	| depth this pidArray debugString |
	depth := 3.
	this := OSProcess thisOSProcess.
	this stdOut ifNil: [self noAccessorAvailable. ^ nil].
	pidArray := Array new: depth.
	(1 to: depth) do: [ :e | | p pid |
		p := this forkSqueak.
		pid := (p == this) ifTrue: [0] ifFalse: [p pid].	"Use Unix fork(2) convention"
		pidArray at: e put: pid].
	debugString := 'pid ', (this pid printString), ' ppid ', (this ppid printString), ' ',
		(pidArray printString), (Character lf asString).
	this stdOut nextPutAll: debugString.
	^ pidArray
]

{ #category : #utility }
UnixProcess class >> env [
	"Note: The #environment selector has special meaning for classes, so use #env."

	"UnixProcess env"

	^ self thisOSProcess environment

]

{ #category : #'child process creation' }
UnixProcess class >> forkHeadlessSqueakAndDo: aBlock [ 
	"Start a new instance of Squeak running in a child OS process, and  
	execute aBlock in the child instance. The new instance is a clone of 
	this image, but without a connection to the X display. The child instance 
	executes aBlock, which hopefully does not involve interaction with the 
	X display; and the parent continues normally.  
	  
	The child should not depend on using existing connections to external  
	resources. For example, the child may lose its connections to stdin, 
	stdout, and stderr after its parent exits."

	"UnixProcess forkHeadlessSqueakAndDo: [UnixProcess helloWorld]"

	^ self thisOSProcess forkHeadlessSqueakAndDo: aBlock


]

{ #category : #'child process creation' }
UnixProcess class >> forkHeadlessSqueakAndDoThenQuit: aBlock [ 
	"Start a new instance of Squeak running in a child OS process, and 
	execute aBlock in the child instance. The new instance is a clone of
	this image, but without a connection to the X display. The child instance
	executes aBlock, which hopefully does not involve interaction with the
	X display; and the parent continues normally.

	The child should not depend on using existing connections to external 
	resources. For example, the child may lose its connections to stdin, stdout,
	and stderr after its parent exits."

	"UnixProcess forkHeadlessSqueakAndDoThenQuit: [UnixProcess helloWorld]"

	^ self thisOSProcess forkHeadlessSqueakAndDoThenQuit: aBlock

]

{ #category : #'child process creation' }
UnixProcess class >> forkJob: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [ 
	"Call Unix vfork() and execve() to create a child process, and answer the 
	child process. Delegate this to the singleton OSProcess>>thisOSProcess."

	^ self thisOSProcess
		forkJob: executableFile
		arguments: arrayOfStrings
		environment: stringDictionary
		descriptors: arrayOf3Streams
]

{ #category : #'child process creation' }
UnixProcess class >> forkSqueak [
	"Start a new instance of Squeak running in a child OS process. The new instance is a
	clone of this image except for the return value of this method. It does not reload the
	image file from disk.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	"UnixProcess forkSqueak"

	^ self thisOSProcess forkSqueak.

]

{ #category : #'child process creation' }
UnixProcess class >> forkSqueakAndDo: aBlock [
	"Start a new instance of Squeak running in a child OS process. The new instance is a
	clone of this image except for the return value of this method. It does not reload the
	image file from disk. The child image evaluates aBlock.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	"UnixProcess forkSqueakAndDo:
		[Object inform: 'Hi, I am the child Squeak process.']"

	^ self thisOSProcess forkSqueakAndDo: aBlock

]

{ #category : #'child process creation' }
UnixProcess class >> forkSqueakAndDoThenQuit: aBlock [
	"Start a new instance of Squeak running in a child OS process. The new instance is a
	clone of this image except for the return value of this method. It does not reload the
	image file from disk. The child image evaluates aBlock.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	"UnixProcess forkSqueakAndDoThenQuit:
		[Object inform: 'Hi, I am the child Squeak process. Click OK to exit the child Squeak.']"

	^ self thisOSProcess forkSqueakAndDoThenQuit: aBlock

]

{ #category : #examples }
UnixProcess class >> headlessChild [
	"Start a new instance of Squeak running in a child OS process. The new
	instance is a nearly identical copy of its parent, resuming execution at the
	same point as the parent, and differentiated only by the return value of
	this method. The child squeak will write a message to standard output,
	then exit."

	"UnixProcess headlessChild"

	| this childBlock |
	this := OSProcess thisOSProcess.
	childBlock :=
		[this stdOut nextPutAll: 'hello world from child process '.
		this pid printOn: OSProcess thisOSProcess stdOut.
		this stdOut nextPut: Character lf ].
	^ self forkHeadlessSqueakAndDoThenQuit: childBlock


]

{ #category : #'platform identification' }
UnixProcess class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for
	the Squeak VM running on the current platform."

	^ self isUnix

]

{ #category : #examples }
UnixProcess class >> listDirectory [
	"Execute a simple command, sending output to standard output."

	"UnixProcess listDirectory"

	| proc |
	proc := self
			forkJob: '/bin/ls'
			arguments: nil
			environment: nil
			descriptors: nil.
	proc ifNil: [self noAccessorAvailable].
	^ proc
]

{ #category : #'utility - VM building' }
UnixProcess class >> makeVmIn: buildDirectoryPathName [
	"Rebuild the virtual machine and plugins in the buildDirectoryPathName
	directory. If the build is successful, save the image and restart using the
	new VM. This assumes that the currently executing VM is either located in,
	or linked to, the buildDirectoryPathName directory."

	"UnixProcess makeVmIn: '/usr/local/squeak/Squeak-2.8/build'"
	"UnixProcess makeVmIn: nil"

	^ self makeVmIn: (buildDirectoryPathName ifNil: ['']) interactive: true


]

{ #category : #'utility - VM building' }
UnixProcess class >> makeVmIn: buildDirectoryPathName interactive: aBoolean [
	"Rebuild the virtual machine and plugins in the buildDirectoryPathName
	directory. If the build is successful, save the image and restart using the
	new VM. This assumes that the currently executing VM is either located in,
	or linked to, the buildDirectoryPathName directory. If aBoolean is true,
	display interactive dialogs, otherwise output goes only to the Transcript."

	"UnixProcess makeVmIn: '/usr/local/squeak/Squeak-2.8/build' interactive: true"

	| commandString result |
	commandString := 'cd ', buildDirectoryPathName, '; make'.
	Transcript cr; show: 'running external command "', commandString, '"'; cr.
	result := self waitForCommandOutputArray: commandString.
	((result at: 3) == 0 and: [(result at: 2) isEmpty])
		ifTrue:
			[Transcript show: 'make completed successfully, restarting VM'; cr.
			aBoolean ifTrue:
				[self inform: 'make completed successfully, restarting VM'].
			self quitAndRestart]
		ifFalse:
			[Transcript show: (result at: 2); cr.
			Transcript show: 'make did not succeed, VM will not be restarted'; cr.
			aBoolean ifTrue:
				[self inform: 'make did not succeed, VM will not be restarted'.
				self inform: (result at: 2)]].
	^ result

]

{ #category : #utility }
UnixProcess class >> path [
	"UnixProcess path"

	^ self thisOSProcess path

]

{ #category : #utility }
UnixProcess class >> programName [

	"UnixProcess programName"

	^ self thisOSProcess programName

]

{ #category : #'X display - deprecated' }
UnixProcess class >> recapitate [
	"Deprecated. See ThisOSProcess>>recapitate"

	"self decapitate. (Delay forSeconds: 5) wait. self recapitate."

	^ OSProcess thisOSProcess recapitate
]

{ #category : #utility }
UnixProcess class >> restartVirtualMachine [
	"Fork a new instance and quit this one. This moves the running VM into a new
	OS process, and starts a new X display for the new process. It does not reload the
	VM program text, so this cannot be used to restart the VM after rebuild."

	"UnixProcess restartVirtualMachine"

	| proc |
	proc := self forkSqueak.
	proc isNil
		ifTrue: 
			[self noAccessorAvailable.
			nil]
		ifFalse:
			[OSProcess thisOSProcess == proc
				ifFalse:
					["Quit if this is the parent process"
					Smalltalk quitPrimitive]].
	^ proc
]

{ #category : #'unit tests' }
UnixProcess class >> runTests [
	"Run a few tests to see if things are working correctly on Unix/Linux. 
	Output is on stdout, stderr, and the Squeak Transcript. One of the tests 
	requires input from stdin, so Squeak should be run from a shell command
	line and not as a background process.

	Warning: This test will crash your VM if your are using the -xshm command
	line option. For reasons which I do not quite understand, the X shared
	memory segment becomes invalid when the Squeak VM which initially
	opened the shared memory exits. The remaining Squeak children will crash
	when then then next try to update the display.

	Note: If you see 'select: Bad file descriptor' messages on your console standard
	output, these are occuring while running headless in the decapitate/recapitate
	tests.

	Important: Prior to evaluating this method, please type one line of text
	followed by a <cr> on the terminal standard input. This provides the
	input for the stdin test. Failing to provide this input prior to evaluating
	the tests will cause one of the test cases to fail."

	"UnixProcess runTests"

	| this s p failures result a |
	failures := 0.
	Transcript show: 'Begin OSProcess tests'; cr.
	Transcript show: 'Test for working ProcessAccessor ... '.
	this := OSProcess thisOSProcess.
	(this pid isKindOf: Integer)
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'Echo one line of text previously entered from stdin ... '.
	s := OSProcess readFromStdIn.
	s size > 0
		ifTrue: [Transcript show: 'OK'; cr; show: s; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'Message to stdout ... '.
	(OSProcess helloWorld isKindOf: AttachableFileStream)
		ifTrue: [Transcript show: 'OK'; cr; show: s; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'Message to stderr ... '.
	(OSProcess helloStdErr isKindOf: AttachableFileStream)
		ifTrue: [Transcript show: 'OK'; cr; show: s; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess cataFile ... '.
	p := UnixProcess catAFile.
	(Delay forSeconds: 1) wait.
	p exitStatus == 0
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess testEnvSet ... '.
	p := UnixProcess testEnvSet.
	(Delay forSeconds: 1) wait.
	p exitStatus == 0
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess catFromFileToFiles ... '.
	OSProcess command: 'rm /tmp/deleteMe.out'.
	OSProcess command: 'rm /tmp/deleteMe.err'.
	p := UnixProcess catFromFileToFiles.
	(Delay forSeconds: 1) wait.
	p exitStatus == 0
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess testRunCommand ... '.
	OSProcess command: 'rm /tmp/deleteMe.out'.
	OSProcess command: 'rm /tmp/deleteMe.err'.
	p := UnixProcess testRunCommand.
	(Delay forSeconds: 1) wait.
	p exitStatus == 256
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess testPipe ... '.
	UnixProcess testPipe = 'this is some text to write into the pipe'
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess testPipeLine ... '.
	UnixProcess testPipeLine = 'This is the text to write out through one pipe, copy through an external cat command, and then read back in through another pipe.'
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess spawnTenHeadlessChildren ... '.
	p := UnixProcess spawnTenHeadlessChildren.
	(p size == 10 and: [(p select: [:e | (e runState == #running) | (e exitStatus == 0)]) size == 10])
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess cloneSqueak ... '.
	p := UnixProcess cloneSqueak.
	(p isKindOf: UnixProcess)
		ifTrue: 
			[(Delay forSeconds: 1) wait.
			OSProcess snapshot: false andQuit: true].
	(Delay forSeconds: 5) wait.
	p exitStatus == 0
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess squeakSqueak ... '.
	p := UnixProcess squeakSqueak.
	(Delay forSeconds: 5) wait.
	OSProcess thisOSProcess sigkill: p.
	(Delay forSeconds: 1) wait.
	p exitStatus == 9
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess restartVirtualMachine ... '.
	p := UnixProcess restartVirtualMachine.
	p pid == OSProcess thisOSProcess pid
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess command: ''cat'' input: ''this is some test data'' ... '.
	p := (OSProcess thisOSProcess
		command: 'cat'
		input: 'this is some test data').
	(Delay forSeconds: 1) wait.
	p upToEnd = 'this is some test data'
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'UnixProcess waitForCommandOutput: ''echo sleeping...; sleep 1; echo I just slept for one second'' ... '.
	('*I just slept for one second*' match:
		(OSProcess thisOSProcess
			waitForCommandOutput: 'echo sleeping...; sleep 1; echo I just slept for one second'))
		ifTrue: [Transcript show: 'OK'; cr]
		ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1].
	Transcript show: 'Unix command pipeline with output and error returned in an array ... '.
	(Smalltalk hasClassNamed: #PipeableOSProcess)
		ifTrue:
			[a := (((Smalltalk at: #PipeableOSProcess) command: 'echo this is a test; BOGUS') | 'cut -c11-14') outputAndError.
			(((a isKindOf: Array)
				and: ['test*' match: (a at: 1)])
					and: ['*BOGUS*' match: (a at: 2)])
						ifTrue: [Transcript show: 'OK'; cr]
						ifFalse: [Transcript show: 'NFG'; cr. failures := failures + 1]]
		ifFalse:
			[Transcript show: 'skipping PipeableOSProcess test (requires CommandShell)'; cr].

	Transcript show: 'UnixProcess decapitate and recapatiate five times'; cr.
	5 timesRepeat:
		[UnixProcess decapitate.
		UnixProcess recapitate].

	failures == 1
		ifTrue: [result := 'OSProcess tests completed with ', failures printString, ' failure']
		ifFalse: [result := 'OSProcess tests completed with ', failures printString, ' failures'].
	Transcript show: result; cr.

	^ result

]

{ #category : #'utility - image save' }
UnixProcess class >> saveImageInBackground [
	"Save image in a background OS process."

	"UnixProcess saveImageInBackground"

	^ self saveImageInBackground: self uniqueNameForSavedImage nice: false

]

{ #category : #'utility - image save' }
UnixProcess class >> saveImageInBackground: savedImageName nice: niceFlag [
	"When Squeak is used as a server it is sometimes desirable to periodically
	save image snapshots. This method forks a headless Squeak to perform a
	snapshot without impacting the server Squeak. Very little additional memory
	is required to do this because Unix copy-on-write memory management allows
	the two Squeak images to share object memory while the save is performed.
	The saved image is given a time stamped name, and the image name of
	the main server Squeak remains unchanged. If niceFlag is true, the
	background OS process runs at lowered scheduling priority."

	^ self forkHeadlessSqueakAndDo:
		[| st |
		"Delay is required in the background process when forking a headless
		Squeak, probably necessary to permit X session stuff to settle down."
		(Delay forMilliseconds: 500) wait.
		(niceFlag notNil and: [niceFlag]) ifTrue:
			["lower priority of background OS process"
			OSProcess accessor nice: 1].
		st := SmalltalkImage current.
		(SourceFiles at: 2) ifNotNil:
			["ensure that copying the changes file will always work"
			st closeSourceFiles.
			st saveChangesInFileNamed: (st fullNameForChangesNamed: savedImageName)].
		st changeImageNameTo: savedImageName,'.image';
			closeSourceFiles;
			openSourceFiles;  "so SNAPSHOT appears in new changes file"
			saveImageSegments;
			snapshot: true andQuit: true]

]

{ #category : #'utility - image save' }
UnixProcess class >> saveImageInBackgroundNicely [
	"Save image in a background OS process with lowered scheduling priority."

	"UnixProcess saveImageInBackgroundNicely"

	^ self saveImageInBackground: self uniqueNameForSavedImage nice: true

]

{ #category : #utility }
UnixProcess class >> sessionID [

	"UnixProcess sessionID"

	^ self thisOSProcess sessionID

]

{ #category : #'X display - deprecated' }
UnixProcess class >> setXDisplayName: xDisplayName [
	"Deprecated. See ThisOSProcess>>setXDisplayName"

	"self setXDisplayName: 'unix:0' "
	"self setXDisplayName: ':1' "

	^ OSProcess thisOSProcess setXDisplayName: xDisplayName


]

{ #category : #examples }
UnixProcess class >> spawnTenHeadlessChildren [
	"Spawn ten Squeak children, each of which writes a message to standard 
	output, then exits. Answer an array of pid values for the child 
	processes. "

	"UnixProcess spawnTenHeadlessChildren"

	| childBlock count children this |
	this := OSProcess thisOSProcess.
	this stdOut ifNil: [self noAccessorAvailable. ^ nil].
	count := 10.
	children := Array new: count.
	childBlock := 
			[this stdOut nextPutAll: 'hello world from child process '.
			this pid printOn: this stdOut.
			this stdOut nextPut: Character lf.
			this stdOut flush].
	(1 to: count)
		do: 
			[:e | 
			OSProcess thisOSProcess stdOut flush.
			children at: e put: (self forkHeadlessSqueakAndDoThenQuit: childBlock)].
	^ children
]

{ #category : #examples }
UnixProcess class >> squeakSqueak [
	"Start a new instance of Squeak running in a child OS process. The new instance
	will restart from the image file, so it is a clone of this image as it existed at the
	most recent image save. See cloneSqueak for an example of how to clone the
	running image without going back to the saved image file."

	"UnixProcess squeakSqueak"

	| proc |
	proc := self squeak.
	proc ifNil: [self noAccessorAvailable].
	^ proc

]

{ #category : #utility }
UnixProcess class >> startSwiki: aSwiki onPort: num loggingTo: aFileName [
	"Start a swiki in a headless Squeak image."

	"UnixProcess startSwiki: 'myswiki' onPort: 8081 loggingTo: 'log.txt'"

	| proc |
	(Smalltalk hasClassNamed: #SwikiAction)
		ifTrue:
			[proc := self forkSqueakAndDo:
				[(Smalltalk at: #SwikiAction) new restore: 'myswiki'.
				(Smalltalk at: #PWS) serveOnPort: num loggingTo: aFileName.
				UnixProcess decapitate].
			proc ifNil: [self noAccessorAvailable].
			^ proc]
		ifFalse:
		[self notify: 'PWS not installed in this image']

]

{ #category : #utility }
UnixProcess class >> stdErr [
	"UnixProcess stdErr"

	^ self thisOSProcess stdErr

]

{ #category : #utility }
UnixProcess class >> stdIn [
	"UnixProcess stdIn"

	^ self thisOSProcess stdIn

]

{ #category : #utility }
UnixProcess class >> stdOut [
	"UnixProcess stdOut"

	^ self thisOSProcess stdOut

]

{ #category : #examples }
UnixProcess class >> testEnvSet [
	"Set up a new environment for a child process. Exec a shell to show the 
	environment variables on the terminal standard output. Note that many 
	shells will set other environment variables in addition to those which we
	set up prior to executing the shell."

	"UnixProcess testEnvSet"

	| e proc |
	e := Dictionary new.
	e at: #KEY1 put: 'value1';
	 at: #KEY2 put: 'value2';
	 at: #KEY3 put: 'value3'.
	proc := self
			forkJob: '/bin/sh'
			arguments: #('-c' 'env' )
			environment: e
			descriptors: nil.
	proc ifNil: [self noAccessorAvailable].
	^ proc
]

{ #category : #examples }
UnixProcess class >> testPipe [
	"Create an OS pipe, write some text to it, and read the text back from the 
	other end of the pipe."

	"UnixProcess testPipe inspect"

	| s p r |
	s := 'this is some text to write into the pipe'.
	p := OSPipe new.
	p ifNil: 
		[self noAccessorAvailable.
		^ p].
	p writer nextPutAll: s.
	p writer close.
	r := p reader next: s size.
	p reader close.
	^ r
]

{ #category : #examples }
UnixProcess class >> testPipeLine [
	"Create two OS pipes, and a child OS process with its input connected to 
	one pipe and its  output connected to the other pipe. Write some text to
	the input pipe, and read the resulting output (just echoed back by the
	Unix cat command) back through the output pipe. Send a SIGHUP signal
	to the child process to tell it to exit.

	This test verifies the ability of Squeak to send text to an external OS process
	through a pipe, and read the output text back from another pipe.
	See ConnectedUnixProcess for a more useful implementation."

	"UnixProcess testPipeLine inspect"

	| testString pipe1 pipe2 input output src dest desc result child |
	OSProcess accessor canAccessSystem ifFalse: [^ nil].
	testString := 'This is the text to write out through one pipe, copy through an external cat command, and then read back in through another pipe.'.
	pipe1 := OSPipe blockingPipe.
	pipe2 := OSPipe nonBlockingPipe.
	input := pipe1 reader.
	output := pipe2 writer.
	src := pipe1 writer.
	dest := pipe2 reader.
	desc := Array
				with: input
				with: output
				with: nil.
	child := self
				forkJob: '/bin/cat'
				arguments: nil
				environment: nil
				descriptors: desc.
	input close.
	output close.
	src nextPutAll: testString.
	src close.
	(Delay forSeconds: 1) wait.
	result := dest next: testString size.
	dest close.
	child sigterm. "Tell the child to exit"
	^ result

]

{ #category : #examples }
UnixProcess class >> testRunCommand [
	"Run the command 'ls -l /etc /etc/noSuchFile'. The output of the 
	command will be in the file '/tmp/deleteMe.out', and the error output
	will be in '/tmp/deleteMe.err'. "

	"UnixProcess testRunCommand"

	| out err desc args proc |
	out := FileStream newFileNamed: '/tmp/deleteMe.out'.
	err := FileStream newFileNamed: '/tmp/deleteMe.err'.
	desc := Array
				with: nil
				with: out
				with: err.
	args := Array
				with: '-l'
				with: '/etc'
				with: '/etc/noSuchFile'
				with: '/etc/anotherNonexistentFile'.
	proc := self
				forkJob: '/bin/ls'
				arguments: args
				environment: nil
				descriptors: desc.
	proc ifNil: [self noAccessorAvailable].
	out close.
	err close.
	^ proc
]

{ #category : #'utility - image save' }
UnixProcess class >> uniqueNameForSavedImage [
	"A time stamped image name that will sort in date order in a directory listing"

	"UnixProcess uniqueNameForSavedImage"

	| now month day hour minute second |
	now := DateAndTime now.
	month := now month asString.
	day := now dayOfMonth asString.
	hour := now hour24 asString.
	minute := now minute asString.
	second := now second asString.
	^ 'squeak-',
		now year asString,
		(month size < 2 ifTrue: ['0', month] ifFalse: [month]),
		(day size < 2 ifTrue: ['0', day] ifFalse: [day]),
		(hour size < 2 ifTrue: ['0', hour] ifFalse: [hour]),
		(minute size < 2 ifTrue: ['0', minute] ifFalse: [minute]),
		(second size < 2 ifTrue: ['0', second] ifFalse: [second])

]

{ #category : #'external command processing' }
UnixProcess class >> waitForCommandOutput: aCommandString [ 
	"Run a command in a shell process. Similar to the system(3) call in the 
	standard C library. The active Smalltalk process waits for completion of
	the external command process."

	"UnixProcess waitForCommandOutput: 'echo sleeping...; sleep 1; echo I just slept for one second'"
	"UnixProcess waitForCommandOutput: 'ThisIsABogusCommand'"

	^ self thisOSProcess waitForCommandOutput: aCommandString

]

{ #category : #'external command processing' }
UnixProcess class >> waitForCommandOutputArray: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in the standard C library.
	The active Smalltalk process waits for completion of the external command process."

	"UnixProcess waitForCommandOutputArray: 'echo Hello world!; ls /NOSUCHFILE'"

	^ self thisOSProcess waitForCommandOutputArray: aCommandString
]

{ #category : #private }
UnixProcess >> argsAsFlatArrayAndOffsets: anArrayOfNullTerminatedStrings [
	"Given anArrayOfNullTerminatedStrings, flatten the array into a string buffer,
	leaving space at the beginning of the buffer for a list of C pointers. Answer
	the string buffer and an array of address offsets. The address offsets may later
	be converted to C pointers and overlaid on the beginning of the buffer, resulting
	in a data structure which can be treated as a C array of strings suitable for
	use as a Unix argv vector."

	"OSProcess thisOSProcess argsAsFlatArrayAndOffsets:
		(UnixProcess arguments collect:
			[:e | e, (Character value: 0) asString])"

	| offset arraySize flatStringArray ws addresses |
	"Preserve offset space to hold address pointers."
	offset := (anArrayOfNullTerminatedStrings size + 1) * self processAccessor sizeOfPointer.
	"Allocate flat strings buffer"
	arraySize := (anArrayOfNullTerminatedStrings collect: [:e | e size]) sum
		+ ((anArrayOfNullTerminatedStrings size + 1) * self processAccessor sizeOfPointer).
	"Flatten the strings out into a buffer, leaving room at the
	beginning of the buffer for an array of addresses."
	flatStringArray := String new: arraySize.
	ws := WriteStream on: flatStringArray.
	offset timesRepeat: [ws nextPut: (Character value: 0)].
	anArrayOfNullTerminatedStrings do: [:e | ws nextPutAll: e].
	"Find address offsets to be used in creating the addresses for the strings."
	ws := WriteStream on: (Array new: anArrayOfNullTerminatedStrings size).
	(anArrayOfNullTerminatedStrings collect: [:e | e size])
		inject: offset into: [:p :e | ws nextPut: p. p + e].
	addresses := ws contents.
	"Results"
	^ Array with: flatStringArray with: addresses

]

{ #category : #accessing }
UnixProcess >> arguments [

	^ arguments

]

{ #category : #environment }
UnixProcess >> chDir: pathString [
	"Change current working directory, and update $PWD if it exists in the environment.
	Answer nil for success, or an error message."

	"OSProcess thisOSProcess chDir: '/tmp'"
	"OSProcess thisOSProcess chDir: '/no/such/path'"
	"OSProcess thisOSProcess chDir: FileDirectory default pathName"

	| realPath result |
	realPath := self processAccessor realpath: pathString.
	realPath ifNil: [realPath := pathString].
	result := self processAccessor chDir: realPath.
	result isNil
		ifTrue:
			[(self environmentAt: #PWD)
				ifNotNil:
					[self environmentAt: #PWD put: realPath.
					^ nil]]
		ifFalse:
			[self inform: realPath, ': ', result.
			^ result]
]

{ #category : #'external command processing' }
UnixProcess >> command: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in the standard C library,
	except that aCommandString runs asynchronously in a child process. The command is
	run by a ConnectedUnixProcess in order to facilitate command pipelines within Squeak."

	"UnixProcess thisOSProcess command: 'ls -l /etc'"

	| proc |
	pid isNil
		ifTrue:
			[self class noAccessorAvailable. ^nil]
		ifFalse:
			[proc := self
					forkJob: ExternalUnixOSProcess defaultShellPath
					arguments: (Array with: '-c' with: aCommandString)
					environment: nil
					descriptors: nil.
			proc ifNil: [self class noAccessorAvailable].
			^ proc]

]

{ #category : #'external command processing' }
UnixProcess >> command: aCommandString input: aStreamOrString [
	"Run a command in a shell process. Similar to the system(3) call in the standard C library,
	except that aCommandString runs asynchronously in a child process."

	"OSProcess thisOSProcess
		command: 'cat'
		input: 'this is some test data'"

	"OSProcess thisOSProcess
		command: 'cat'
		input: (ReadStream on: 'this is some test data')"

	| proc |
	(Smalltalk hasClassNamed: #PipeableOSProcess)
		ifTrue:
			[proc := (Smalltalk at: #PipeableOSProcess) command: aCommandString.
			proc ifNil: [^ nil].
			proc nextPutAll: aStreamOrString contents.
			proc pipeToInput close.
			^ proc]
		ifFalse:
			[self notify: 'the #command:input: method requires CommandShell, using #command: instead'.
			^ self command: aStreamOrString contents]


]

{ #category : #private }
UnixProcess >> envAsFlatArrayAndOffsets: anEnvironmentDictionary [
	"Given anEnvironmentDictionary, flatten the dictionary into a string buffer,
	leaving space at the beginning of the buffer for a list of C pointers. Answer
	the string buffer and an array of address offsets. The address offsets may later
	be converted to C pointers and overlaid on the beginning of the buffer, resulting
	in a data structure which can be treated as a C array of strings suitable for
	use as a Unix process environment."

	"OSProcess thisOSProcess envAsFlatArrayAndOffsets: UnixProcess env"

	| offset envArray arraySize flatStringArray ws addresses |
	"Preserve offset space to hold address pointers."
	offset := (anEnvironmentDictionary size + 1) * self processAccessor sizeOfPointer.
	"Build collection of environment strings"
	envArray := OrderedCollection new.
	anEnvironmentDictionary keysAndValuesDo: [:k :v | envArray add: (k, '=', v)].
	"Allocate flat strings buffer"
	arraySize := ((envArray collect: [:e | e size + 1]) sum) + offset.
	"Flatten the strings out into a buffer, leaving room at the beginning of
	the buffer for an array of addresses."
	flatStringArray := String new: arraySize.
	ws := WriteStream on: flatStringArray.
	offset timesRepeat: [ws nextPut: (Character value: 0)].
	envArray do: [:e | ws nextPutAll: e; nextPut: (Character value: 0)].
	"Find address offsets to be used in creating the addresses for the strings."
	ws := WriteStream on: (Array new: anEnvironmentDictionary size).
	(envArray collect: [:e | e size + 1])
		inject: offset into: [:p :e | ws nextPut: p. p + e].
	addresses := ws contents.
	"Results"
	^ Array with: flatStringArray with: addresses

]

{ #category : #accessing }
UnixProcess >> environment [

	^ environment

]

{ #category : #environment }
UnixProcess >> environmentAt: aSymbol [
	"Answer an environment variable for the external OS process, and update the dictionary
	in this Smalltalk object."

	^ environment at: aSymbol asSymbol ifAbsent: []

]

{ #category : #environment }
UnixProcess >> environmentAt: aSymbol put: aString [
	"Set an environment variable for the external OS process, and update the dictionary in
	this Smalltalk object."

	| s |
	self initialize.
	s := self processAccessor environmentAt: aSymbol put: aString.
	s ifNotNil: [ self environment at: aSymbol asSymbol put: aString ].
	^ s


]

{ #category : #finalization }
UnixProcess >> finalize [
	"Use this to release any external resources prior to reinitializing."

	super finalize.
	stdIn := stdIn ifNotNil:
		[[stdIn close; release] on: Error do: [:ex | ].
		nil].
	stdIn := stdOut ifNotNil:
		[[stdOut close; release] on: Error do: [:ex | ].
		nil].
	stdIn := stdErr ifNotNil:
		[[stdErr close; release] on: Error do: [:ex | ].
		nil].
	sessionID := nil.
	ppid := nil.
	programName := nil.
	arguments := nil.
	path := nil.
	environment := nil.
	self updateAllMyChildren.
	allMyChildren := nil.
	processAccessor
		ifNotNil: 
			[processAccessor removeDependent: self.
			processAccessor := nil]

]

{ #category : #'child process creation' }
UnixProcess >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [ 

	"Call Unix vfork() and execve() to create a child process, and answer the 
	child process. This method is expected to be called by class side methods."

	^ ExternalUnixOSProcess
		forkAndExec: executableFile
		arguments: arrayOfStrings
		environment: stringDictionary
		descriptors: arrayOf3Streams
]

{ #category : #'child process creation' }
UnixProcess >> forkHeadlessSqueak [
	"Just like forkSqueak, except that the child Squeak continues headless."

	| thisPid childPid child connected |
	stdOut ifNil: [^ nil].
	self stdOut flush.
	self stdErr flush.
	thisPid := self pid.
	connected := self processAccessor canControlXDisplay
					and: [self flushXDisplay notNil].
	childPid := self processAccessor forkSqueak.
	childPid == 0
		ifTrue:
			[connected ifTrue: [self disconnectXDisplay].
			OSProcess thisOSProcess processAccessor changed: #pid.
			^ self]
		ifFalse:
			[child := ExternalUnixOSProcess new.
			child pid: childPid.
			child ppid: thisPid.
			child programName: self programName.
			child initialStdIn: self stdIn.	
			child initialStdOut: self stdOut.
			child initialStdErr: self stdErr.
			child arguments: self arguments.
			child initialEnvironment: self environment.
			child notYetRunning.
			self registerChildProcess: child.
			child running.
			^ child]

]

{ #category : #'child process creation' }
UnixProcess >> forkHeadlessSqueakAndDo: aBlock [ 
	"Start a new instance of Squeak running in a child OS process, and  
	execute aBlock in the child instance. The new instance is a clone of 
	this image, but without a connection to the X display. The child instance 
	executes aBlock, which hopefully does not involve interaction with the 
	X display; and the parent continues normally.  
	  
	The child should not depend on using existing connections to external  
	resources. For example, the child may lose its connections to stdin, 
	stdout, and stderr after its parent exits."

	| childOrThisProc |
	childOrThisProc := self forkHeadlessSqueak.
	childOrThisProc
		ifNil: 
			[self class noAccessorAvailable.
			^ nil].
	childOrThisProc == self
		ifTrue:
			["Child process"
			aBlock value].
	^ childOrThisProc

]

{ #category : #'child process creation' }
UnixProcess >> forkHeadlessSqueakAndDoThenQuit: aBlock [ 
	"Start a new instance of Squeak running in a child OS process, and 
	execute aBlock in the child instance. The new instance is a clone of
	this image, but without a connection to the X display. The child instance
	executes aBlock, which hopefully does not involve interaction with the
	X display; and the parent continues normally.

	The child should not depend on using existing connections to external 
	resources. For example, the child may lose its connections to stdin, stdout,
	and stderr after its parent exits."

	"self thisOSProcess forkHeadlessSqueakAndDoThenQuit:
		[OSProcess thisOSProcess stdOut nextPutAll: 'hello world!'; nextPut: Character lf]"
	"self thisOSProcess forkHeadlessSqueakAndDoThenQuit: [OSProcess thisOSProcess command: 'xeyes']"

	| childOrThisProc |
	childOrThisProc := self forkHeadlessSqueak.
	childOrThisProc
		ifNil: 
			[self class noAccessorAvailable.
			^ nil].
	childOrThisProc == self
		ifTrue:
			["Child process"
			aBlock value.
			Smalltalk quitPrimitive].
	^ childOrThisProc
]

{ #category : #'child process creation' }
UnixProcess >> forkJob: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [
	"Call Unix vfork() and execve() to create a child process, and answer the child process.
	Delegate this to the singleton OSProcess>>thisOSProcess."

	^ self forkAndExec: executableFile
		arguments: arrayOfStrings
		environment: stringDictionary
		descriptors: arrayOf3Streams

]

{ #category : #'child process creation' }
UnixProcess >> forkSqueak [
	"Fork a child and continue running this Squeak image in both the parent and the child.
	Parent and child are distinguished by the pid returned by primForkSqueak.

	If continuing as the parent process, answer the ExternalUnixOSProcess which
	represents the child. This can be inspected to watch the run state of the child
	process from the parent.

	If continuing as the child process, answer OSProcess thisOSProcess. This can be
	inspected to watch the full state of the child process from the child. The
	child cannot directly view the state of its parent.

	Parent and child should be cautious about using shared connections to external
	resources."

	"self thisOSProcess forkSqueak"

	| thisPid childPid child connected |
	stdOut ifNil: [^ nil].
	self stdOut flush.
	self stdErr flush.
	thisPid := self pid.
	connected := self processAccessor canControlXDisplay
					and: [self flushXDisplay notNil].
	childPid := self processAccessor forkSqueak.
	childPid == 0
		ifTrue:
			[connected ifTrue: [self disconnectXDisplay; recapitate].
			OSProcess thisOSProcess processAccessor changed: #pid.
			^ self]
		ifFalse:
			[child := ExternalUnixOSProcess new.
			child pid: childPid.
			child ppid: thisPid.
			child programName: self programName.
			child initialStdIn: self stdIn.	
			child initialStdOut: self stdOut.
			child initialStdErr: self stdErr.
			child arguments: self arguments.
			child initialEnvironment: self environment.
			child notYetRunning.
			self registerChildProcess: child.
			child running.
			^ child]

]

{ #category : #'child process creation' }
UnixProcess >> forkSqueakAndDo: aBlock [
	"Start a new instance of Squeak running in a child OS process. The new instance is a
	clone of this image except for the return value of this method. It does not reload the
	image file from disk. The child image evaluates aBlock.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	"UnixProcess thisOSProcess forkSqueakAndDo:
		[Object inform: 'Hi, I am the child Squeak process.']"

	| childOrThisProc |
	childOrThisProc := self forkSqueak.
	(childOrThisProc == self) ifTrue: [aBlock value]. "Child process"
	^ childOrThisProc
]

{ #category : #'child process creation' }
UnixProcess >> forkSqueakAndDoThenQuit: aBlock [
	"Start a new instance of Squeak running in a child OS process. The new instance is a
	clone of this image except for the return value of this method. It does not reload the
	image file from disk. The child image evaluates aBlock.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	"UnixProcess thisOSProcess forkSqueakAndDoThenQuit:
		[Object inform: 'Hi, I am the child Squeak process.']"

	| childOrThisProc |
	childOrThisProc := self forkSqueak.
	(childOrThisProc == self)
		ifTrue:
			[ aBlock value.
			Smalltalk quitPrimitive]. "Child process"
	^ childOrThisProc
]

{ #category : #private }
UnixProcess >> getArgumentList [
	"Answer the argument list using anOSProcessAccessor. For Unix, the first element of the list
	would be the program name. This element will not be treated as an argument; rather, it is
	stored as the programName instance variable."

	| index val list |
	list := OrderedCollection new.
	index := 2.
	[(val := processAccessor primArgumentAt: index) notNil] whileTrue: [
		list add: val.
		index := index + 1].
	^ list asArray


]

{ #category : #environment }
UnixProcess >> getCwd [
	"Get current working directory. At image startup, this is equivalent to
	evaluating environmentAt: #PWD"

	"OSProcess thisOSProcess getCwd"

	^ self processAccessor primGetCurrentWorkingDirectory



]

{ #category : #private }
UnixProcess >> getEnvironmentDictionary [
	"Answer an environment dictionary using an OSProcessAccessor."

	| index str key val env |
	env := Dictionary new.
	index := 1.
	[(str := processAccessor primEnvironmentAt: index) notNil] whileTrue: [
		key := (str copyUpTo: $=) asSymbol.
		val := (str copyFrom: ((str indexOf: $=) + 1) to: (str size)).
		env at: key put: val.
		index := index + 1].
	^ env



]

{ #category : #private }
UnixProcess >> getProgramName [
	"Answer the name of the program which is being run by this OS process. Assume the
	Unix convention where the first element of (char **)argv is the program name."

	^ programName := processAccessor primArgumentAt: 1

]

{ #category : #'initialize - release' }
UnixProcess >> initialize [
	"Set my instance variables to reflect the state of the OS process in which 
	this Smalltalk virtual machine is executing."

	super initialize.
	(self processAccessor notNil and: [processAccessor canAccessSystem])
		ifTrue: 
			[self refreshFromProcessAccessor]
		ifFalse: 
			[stdIn := nil.
			stdOut := nil.
			stdErr := nil].
	processAccessor restartChildWatcherProcess

]

{ #category : #'initialize - release' }
UnixProcess >> initializeAllMyChildren [

	^ allMyChildren := Dictionary new

]

{ #category : #'platform identification' }
UnixProcess >> isResponsibleForThisPlatform [
	"Answer true is this is an instance of the class which is responsible for representing
	the OS process for the Squeak VM running on the current platform. A false answer is
	usually the result of running the image on a different platform and VM."

	^ self class isUnix

]

{ #category : #'VM atexit' }
UnixProcess >> killCurrentChildrenAtExit [
	"Arrange for the currently active child processes to receive a SIGTERM
	signal then the Squeak VM exits. Each invokation of this method overrides
	the effects of any previous calls."

	"OSProcess thisOSProcess killCurrentChildrenAtExit"

	self processAccessor killOnVmExit: allMyChildren withSignal: nil

]

{ #category : #private }
UnixProcess >> needsRefresh [
	"Answer true if the sessionID variable is out of date with respect to the running OS Process."

	^ ((sessionID ~= (self processAccessor primGetSession)) | (pid ~= (self processAccessor primGetPid)))

]

{ #category : #accessing }
UnixProcess >> path [

	^ path := self pathString

]

{ #category : #accessing }
UnixProcess >> path: aPathString [

	self environmentAt: #PATH put: aPathString.
	path := self pathString
]

{ #category : #private }
UnixProcess >> pathString [
	"Answer the path string from the environment. Assume Unix convention in which the
	path name is a colon delimited string stored in the PATH environment variable."

	^ self environment at: #PATH ifAbsent: [nil]
]

{ #category : #accessing }
UnixProcess >> pid [

	^ pid := self processAccessor primGetPid

]

{ #category : #accessing }
UnixProcess >> ppid [
	"Always refresh ppid from the processAccessor, because it is possible for a child
	to be reparented when the parent exits. The child does not know about this, so
	we refresh ppid on every access."

	^ ppid := processAccessor primGetPPid

]

{ #category : #printing }
UnixProcess >> printOn: aStream [
	"In English, say 'a Unix' rather than 'an Unix'. Therefore do not use super printOn, which
	treats $U as a vowel."

	self ppid.		"Force update of ppid, in case parent may have exited."
	aStream nextPutAll: 'a ';
			nextPutAll: self class name;
			nextPutAll: ' with pid ';
			nextPutAll: self pid printString

]

{ #category : #'child process creation' }
UnixProcess >> processProxy: anExternalProcess forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [
	"Call Unix vfork() and execve() to create a child process, and answer the child process.
	This method is expected to be called by class side methods. Prepare the arguments before
	calling the primitive, including null termination of all strings. anExternalProcess is an
	object which represents the new child process, and which responds to the #pid: message."

	| nullString progName args argVecAndOffsets argVec argOffsets
	envVecAndOffsets envVec envOffsets in out err childPid pwd |
	stdOut ifNil: [^ nil].
	nullString := (Character value: 0) asString.
	progName := executableFile, nullString.		"Null terminated string"
	arrayOfStrings isNil							"Should be a (possibly empty) array"
		ifTrue:
			[args := Array with: progName]		"First argument is the program name (Unix convention)"
		ifFalse:
			[args := (OrderedCollection new: arrayOfStrings size + 2)
						add: progName;
						addAll: (arrayOfStrings collect: [:e | e, nullString ]);	"Null terminate each string"
						yourself;
						asArray].
	argVecAndOffsets := self argsAsFlatArrayAndOffsets: args.
	argVec := argVecAndOffsets at: 1.
	argOffsets := argVecAndOffsets at: 2.
	(stringDictionary notNil and: [stringDictionary ~= (self environment)])
		ifTrue:
			[envVecAndOffsets := self envAsFlatArrayAndOffsets: stringDictionary.
			envVec := envVecAndOffsets at: 1.
			envOffsets := envVecAndOffsets at: 2]
		ifFalse:
			[envVec := nil.
			envOffsets := nil].	"Same as current environment, so just pass nil."
	arrayOf3Streams isNil
		ifTrue:
			[in := self handleFromAccessor: (self stdIn ioHandle).
			out := self handleFromAccessor: (self stdOut ioHandle).
			err := self handleFromAccessor: (self stdIn ioHandle)]
		ifFalse:
			[(arrayOf3Streams at: 1)
				isNil
					ifTrue: [in := self handleFromAccessor: (self stdIn ioHandle)]
					ifFalse: [in := self handleFromFileStream: (arrayOf3Streams at: 1)].			
			(arrayOf3Streams at: 2)
				isNil
					ifTrue: [ out := self handleFromAccessor: (self stdOut ioHandle)]
					ifFalse: [ out := self handleFromFileStream: (arrayOf3Streams at: 2)].
			(arrayOf3Streams at: 3)
				isNil
					ifTrue: [ err := self handleFromAccessor: (self stdErr ioHandle)]
					ifFalse: [ err := self handleFromFileStream: (arrayOf3Streams at: 3)]].
	pwd := anExternalProcess pwd.
	(pwd = self getCwd)
		ifTrue: [pwd := nil]
		ifFalse: [pwd := pwd, nullString].
	childPid := self processAccessor
				forkAndExec: progName
				stdIn: in
				stdOut: out
				stdErr: err
				argBuf: argVec
				argOffsets: argOffsets
				envBuf: envVec
				envOffsets: envOffsets
				workingDir: pwd.
	anExternalProcess pid: childPid.
	anExternalProcess ppid: self pid.
	((childPid == 0) or: [childPid isNil])
		ifTrue:
			[anExternalProcess unknownRunState]
		ifFalse:
			[anExternalProcess running.
			self registerChildProcess: anExternalProcess].
	^ anExternalProcess

]

{ #category : #accessing }
UnixProcess >> programName [

	^ programName

]

{ #category : #accessing }
UnixProcess >> pthread [
	"The identity of the pthread in which the interpreter executes.
	Always refresh pthread from the processAccessor, because it is possible for a child
	to be reparented when the parent exits. The child does not know about this, so
	we refresh pthread on every access."

	^ pthread := processAccessor getThreadID

]

{ #category : #'IO redirection' }
UnixProcess >> redirect: aFileStream to: newFileStream [

	| oldfd newfd |
	oldfd := self processAccessor unixFileNumber: aFileStream fileID.
	newfd := self processAccessor unixFileNumber: newFileStream fileID.
	self processAccessor primUnixFileClose: oldfd.
	^ self processAccessor primDup: newfd to: oldfd

]

{ #category : #'IO redirection' }
UnixProcess >> redirectStdErrTo: fileStream [
	"Redirect the standard error stream to another output stream."

	^ self redirect: self stdErr to: fileStream

]

{ #category : #'IO redirection' }
UnixProcess >> redirectStdInTo: fileStream [
	"Redirect the standard input stream to another input stream."

	^ self redirect: self stdIn to: fileStream

]

{ #category : #'IO redirection' }
UnixProcess >> redirectStdOutTo: fileStream [
	"Redirect the standard output stream to another output stream."

	"| pipe |
	pipe := OSPipe nonBlockingPipe.
	OSProcess thisOSProcess redirectStdOutTo: pipe writer.
	pipe"
	
	^ self redirect: self stdOut to: fileStream

]

{ #category : #updating }
UnixProcess >> refreshFromProcessAccessor [
	"Set my instance variables to reflect the state of the OS process in which this Smalltalk
	virtual machine is executing."

	self needsRefresh ifTrue: [
		sessionID := self processAccessor getSessionIdentifier.
		pid := processAccessor primGetPid.
		ppid := processAccessor primGetPPid.
		pthread := processAccessor getThreadID.
		self setStdIn.
		self setStdOut.
		self setStdErr.
		programName := self getProgramName.
		arguments := self getArgumentList.
		environment := self getEnvironmentDictionary.
		path := self pathString.
		self updateAllMyChildren]

]

{ #category : #'child process management' }
UnixProcess >> registerChildProcess: anOSProcess [

	self processAccessor sigChldSemaphore.
	self processAccessor grimReaperProcess.	 "Start the reaper process if it is not running."
	accessProtect
		critical: [allMyChildren
				at: anOSProcess pid
				put: anOSProcess].
	^ anOSProcess

]

{ #category : #'OS signal sending' }
UnixProcess >> sigabrt: anExternalOSProcess [
	"Send a SIGABRT signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigabrtTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigalrm: anExternalOSProcess [
	"Send a SIGALRM signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigalrmTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigchld: anExternalOSProcess [
	"Send a SIGCHLD signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigchldTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigcont: anExternalOSProcess [
	"Send a SIGCONT signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigcontTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sighup: anExternalOSProcess [
	"Send a SIGHUP signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSighupTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigint: anExternalOSProcess [
	"Send a SIGINT signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigintTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigkill: anExternalOSProcess [
	"Send a SIGKILL signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigkillTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigpipe: anExternalOSProcess [
	"Send a SIGPIPE signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigpipeTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigquit: anExternalOSProcess [
	"Send a SIGQUIT signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigquitTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigstop: anExternalOSProcess [
	"Send a SIGSTOP signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigstopTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigterm: anExternalOSProcess [
	"Send a SIGTERM signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigtermTo: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigusr1: anExternalOSProcess [
	"Send a SIGUSR1 signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigusr1To: anExternalOSProcess pid
]

{ #category : #'OS signal sending' }
UnixProcess >> sigusr2: anExternalOSProcess [
	"Send a SIGUSR2 signal to the external process represented by anExternalOSProcess."

	^ self processAccessor primSendSigusr2To: anExternalOSProcess pid
]

{ #category : #'child process creation' }
UnixProcess >> squeak [
	"Start a new instance of Squeak running in a child OS process. The new 
	instance will restart from the image file, so it is a clone of this image 
	as it existed at the most recent image save."

	"OSProcess thisOSProcess squeak"

	^ self
		forkJob: self programName
		arguments: self arguments
		environment: nil
		descriptors: nil
]

{ #category : #'child process management' }
UnixProcess >> unregisterChildProcess: anOSProcess [

	accessProtect
		critical: [allMyChildren
				removeKey: self pid
				ifAbsent: []].
	^ anOSProcess

]

{ #category : #updating }
UnixProcess >> update: aParameter [
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
		[processAccessor := processAccessor ifNotNil: [processAccessor removeDependent: self. nil].
		^ self].
	self error: 'Unexpected update parameter'
]

{ #category : #'external command processing' }
UnixProcess >> waitForCommand: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in the standard C library.
	The active Smalltalk process waits for completion of the external command process. This just
	uses a simple polling loop, which is not very elegant but works well enough for most purposes."

	"OSProcess thisOSProcess waitForCommand: 'echo sleeping...; sleep 3; echo I just slept for three seconds'"

	| proc d |
	d := Delay forMilliseconds: 50.
	proc := self
		forkJob: ExternalUnixOSProcess defaultShellPath
		arguments: (Array with: '-c' with: aCommandString)
		environment: nil
		descriptors: nil.
	proc ifNil: [self class noAccessorAvailable].
	[proc runState == #complete] whileFalse: [d wait].
	^ proc

]

{ #category : #'external command processing' }
UnixProcess >> waitForCommandOutput: aCommandString [ 
	"Run a command in a shell process. Similar to the system(3) call in the 
	standard C library. The active Smalltalk process waits for completion of
	the external command process."

	"OSProcess thisOSProcess waitForCommandOutput: 'echo sleeping...; sleep 1; echo I just slept for one second'"
	"OSProcess thisOSProcess waitForCommandOutput: 'ThisIsABogusCommand'"
	"OSProcess thisOSProcess waitForCommandOutput: '/bin/ls -l /etc /bin'"
	"OSProcess thisOSProcess waitForCommandOutput: 'echo Hello world!; ls /NOSUCHFILE'"

	(Smalltalk hasClassNamed: #PipeableOSProcess)
		ifTrue:
			[^ ((Smalltalk at: #PipeableOSProcess) command: aCommandString) output]
		ifFalse:
			[self notify: 'the #waitForCommandOutput: method requires CommandShell'.
			^ '']

]

{ #category : #'external command processing' }
UnixProcess >> waitForCommandOutputArray: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in the standard C library.
	The active Smalltalk process waits for completion of the external command process."

	"OSProcess thisOSProcess waitForCommandOutputArray: 'echo Hello world!; ls /NOSUCHFILE'"

	| proc |
	(Smalltalk hasClassNamed: #PipeableOSProcess)
		ifTrue:
			[proc := (Smalltalk at: #PipeableOSProcess) command: aCommandString.
			^ Array
				with: proc output
				with: proc errorUpToEnd
				with: proc processProxy exitStatus]
		ifFalse:
			[self notify: 'the #waitForCommandOutputArray: method requires CommandShell'.
			^ Array with: '' with: '' with: nil]

]
