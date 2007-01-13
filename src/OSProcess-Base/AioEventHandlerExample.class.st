"
Demonstrate asynchronous read handers for file streams, OS pipes, standard input, and sockets. See class category ""examples"". Some examples require OSProcess.
"
Class {
	#name : #AioEventHandlerExample,
	#superclass : #Object,
	#instVars : [
		'handler',
		'ioStream'
	],
	#category : #'OSProcess-AIO'
}

{ #category : #examples }
AioEventHandlerExample class >> osPipeExample [
	"Demonstrate an asynchronous read hander on an OS pipe. Output will
	be displayed on the Transcript."

	"self osPipeExample"

	| pipe aio |
	(Smalltalk hasClassNamed: #OSProcess)
		ifFalse:
			[self notify: 'this example requires OSProcess']
		ifTrue:
			[pipe _ (Smalltalk at: #OSPipe) new.
			aio _ super new handler: (AioEventHandler for: pipe reader); ioStream: pipe reader.
			aio handler addDependent: aio.
			(1 to: 10) do:
				[:i |
				pipe nextPutAll: 'this is line ', i asString; cr.
				(Delay forMilliseconds: 500) wait].
			^ aio handler close]

]

{ #category : #examples }
AioEventHandlerExample class >> showTtyOnTranscript: ttyName [
	"Enter lines on /dev/tty, and watch them show up on the Transcript. Normally,
	/dev/tty corresponds to standard input for the Squeak process, so if you have
	a serial port connected to something that generates data, try this example with
	/dev/whatever to demonstrate asych input on a serial port.

	Warning: This method does not set the file stream for nonblocking input, so
	it can block the Squeak VM. The #getAvailableData attempts to work around this,
	but save your image before testing with another serial interfaces."

	"self showTtyOnTranscript: '/dev/tty'"

	| inputStream handler example |
	inputStream _ FileStream readOnlyFileNamed: '/dev/tty'.
	handler _ AioEventHandler for: inputStream
				exceptions: true
				readEvents: true
				writeEvents: false.
	example _ super new handler: handler; ioStream: inputStream.
	handler addDependent: example.
	Transcript cr; show: ''.
	self notify: 'Enter lines on ', ttyName, ', watch the Transcript, and select "Proceed" when done'.
	^ example handler close

]

{ #category : #examples }
AioEventHandlerExample class >> standardInputExample [
	"Enter lines on stdin, and watch them show up on the Transcript."

	"self standardInputExample"

	| aio stdin |
	(Smalltalk hasClassNamed: #OSProcess)
		ifFalse:
			[self notify: 'this example requires OSProcess']
		ifTrue:
			[Transcript cr; show: ''.
			stdin _ (Smalltalk at: #OSProcess) thisOSProcess stdIn.
			aio _ super new handler: (AioEventHandler for: stdin); ioStream: stdin.
			aio handler addDependent: aio.
			self notify: 'Enter lines on standard input, watch the Transcript, and select "Proceed" when done'.
			^ aio handler close]

]

{ #category : #examples }
AioEventHandlerExample class >> tcpSocketExample [
	"Loosely based on OldSocket>>remoteTestServerTCP. Output is displayed on the Transcript."

	"self tcpSocketExample"

	| port serverTcpSocket serverName clientTcpSocket handler example useOldStyleSockets |
	port _ 8086.
	serverName _ '127.0.0.1'.

	"The networking code was updated for Squeak 3.6. This checks for which version to use."
	useOldStyleSockets _ Socket respondsTo: #initializeNetworkIfFail:.

	Transcript show: 'initializing network ... '.

	useOldStyleSockets
		ifTrue:
			[Socket initializeNetworkIfFail: [^Transcript show:'failed']]
		ifFalse:
			[[Socket initializeNetwork]
				on: Error
				do: [:ex | ^Transcript show:'failed']].
	Transcript show:'ok';cr.

	"Create the server (reader) socket"
	serverTcpSocket _ Socket newTCP.
	serverTcpSocket listenOn: port.
	[Transcript show: 'server endpoint created on port ', port asString; cr.
	useOldStyleSockets
		ifTrue:
			[serverTcpSocket waitForConnectionUntil: Socket standardDeadline]
		ifFalse:
			[serverTcpSocket waitForConnectionFor: 10]] fork.
	(Delay forMilliseconds: 1000) wait.

	"Create the client (writer) socket"
	clientTcpSocket _ Socket newTCP.
	clientTcpSocket connectTo: (NetNameResolver addressFromString: serverName) port: port.
	useOldStyleSockets
		ifTrue:
			[clientTcpSocket waitForConnectionUntil: Socket standardDeadline]
		ifFalse:
			[clientTcpSocket waitForConnectionFor: 10].
	Transcript show: 'client endpoint connected to ', serverName, ' port ', port asString; cr.

	"Set up a read event handler on the server socket"
	handler _ AioEventHandler for: serverTcpSocket
				exceptions: true
				readEvents: true
				writeEvents: false.
	example _ super new handler: handler; ioStream: serverTcpSocket.
	handler addDependent: example.
	Transcript show: 'event handler started'; cr.

	"Send a few lines of data to the client socket, waiting briefly between lines.
	The event handler will watch the server socket, and copy data to the Transcript
	each time a new line of data is available to the server."
	(1 to: 10) do:
		[:i |
		clientTcpSocket sendData: 'this is line ', i asString, Character cr asString.
		(Delay forMilliseconds: 500) wait].

	clientTcpSocket closeAndDestroy.
	Transcript show: 'client endpoint closed'; cr.
	serverTcpSocket closeAndDestroy.
	Transcript show: 'server endpoint closed'; cr.
	example close.
	Transcript show: 'event handler stopped'; cr.
	^ Array with: example with: serverTcpSocket with: clientTcpSocket
]

{ #category : #'version identification' }
AioEventHandlerExample class >> versionString [

	^ '1.2'
]

{ #category : #'initialize-release' }
AioEventHandlerExample >> close [

	self handler close.
	self handler removeDependent: self

]

{ #category : #updating }
AioEventHandlerExample >> getAvailableData [
	"Obtain all available data from ioStream. For a FileStream, keep reading until
	a line terminator is reached. This allows use with a FileStream that has not been
	set for nonblocking input."

	| ws c buffer n |
	buffer _ String new: 4000.
	(self ioStream isKindOf: FileStream)
		ifTrue:
			[ws _ WriteStream on: ''.
			[c _ ioStream next.
			(c == Character lf)
				ifTrue: [ws nextPut: Character cr]
				ifFalse: [ws nextPut: c].
			(c ~= Character lf) and: [c ~= Character cr]] whileTrue.
			^ ws contents]
		ifFalse:
			[ioStream dataAvailable
				ifTrue:
					[n _ ioStream receiveDataInto: buffer.
					^ buffer copyFrom: 1 to: n]
				ifFalse:
					[^ '']]

]

{ #category : #accessing }
AioEventHandlerExample >> handler [

	^ handler
]

{ #category : #accessing }
AioEventHandlerExample >> handler: anAioHandler [

	handler _ anAioHandler
]

{ #category : #accessing }
AioEventHandlerExample >> ioStream [

	^ ioStream
]

{ #category : #accessing }
AioEventHandlerExample >> ioStream: aFileStream [

	ioStream _ aFileStream
]

{ #category : #updating }
AioEventHandlerExample >> update: anObject [

	(anObject isKindOf: AioEventHandler)
		ifTrue: [Transcript show: self getAvailableData]

]
