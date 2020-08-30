"
Test AioEventHandler and AioPlugin. Provides fair coverage of IO readable events, minimal coverage of IO writable events, and no real coverage for IO exception events. The writable events and exception events probably work, but this test suite will not prove it.
"
Class {
	#name : #AioEventHandlerTestCase,
	#superclass : #TestCase,
	#category : #'OSProcess-Tests'
}

{ #category : #running }
AioEventHandlerTestCase >> tearDown [
	temporaryFileStream ifNotNil: [
		temporaryFileStream close.
		temporaryFileStream file delete ].
	
	super tearDown
]

{ #category : #accessing }
AioEventHandlerTestCase >> temporaryFileStream [
	^ temporaryFileStream ifNil: [
		temporaryFileStream := (FileLocator temp / UUID new asString) unbufferedBinaryWriteStream ].
]

{ #category : #testing }
AioEventHandlerTestCase >> testEnableHandleAndDisable [

	| eventHandler anOpenFile fileHandle aioHandleResult sema semaIndex aioEnableResult aioDisableResult |
	eventHandler := AioEventHandler new.
	anOpenFile := OSProcess fileNamed: 'delete.me'.
	fileHandle := eventHandler handleForFile: anOpenFile.
	sema := Semaphore new.
	[semaIndex := Smalltalk registerExternalObject: sema.
	[aioEnableResult := eventHandler
			aioEnable: fileHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].
	self assert: semaIndex == aioEnableResult.
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: true
		readEvents: true
		writeEvents: true.
	self assert: aioHandleResult == 2r0111. "return bitmask, all three bits set"
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: true
		readEvents: false
		writeEvents: true.
	self assert: aioHandleResult == 2r0101.
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: false
		writeEvents: true.
	self assert: aioHandleResult == 2r0100.
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: true
		readEvents: false
		writeEvents: false.
	self assert: aioHandleResult == 2r0001.
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: false
		writeEvents: false.
	self assert: aioHandleResult == 2r0000.
	aioDisableResult := eventHandler aioDisable: fileHandle.
	self assert: aioDisableResult == fileHandle]
		ensure:
			[Smalltalk unregisterExternalObject: sema.
			(fileHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: fileHandle]].
	anOpenFile close.
	OSProcess deleteFileNamed: 'delete.me'.

]

{ #category : #testing }
AioEventHandlerTestCase >> testFileReadableEvent [

	| eventHandler anOpenFile fileHandle aioHandleResult sema semaIndex aioEnableResult fileName |
	fileName := 'DeleteThisTemporaryFile'.

	eventHandler := AioEventHandler new.
	OSProcess deleteFileNamed: fileName.
	[anOpenFile := OSProcess fileNamed: fileName.
	fileHandle := eventHandler handleForFile: anOpenFile.
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	[aioEnableResult := eventHandler
			aioEnable: fileHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].
	self assert: semaIndex == aioEnableResult.

	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	self assert: aioHandleResult == 2r010.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but readable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin reading data based on having received this initial signal."
	sema wait. "consume the signal"
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self deny: sema isSignaled. "Nothing has happened to indicate more data available."

	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	self assert: aioHandleResult == 2r010.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but readable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin reading data based on having received this initial signal."
	sema wait. "consume the signal"
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self deny: sema isSignaled. "Nothing has happened to indicate more data available."

	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	self assert: aioHandleResult == 2r010.
	anOpenFile nextPutAll: 'write some stuff to the file'; flush.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but readable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin reading data based on having received this initial signal."
	sema wait. "consume the signal"

	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	self assert: aioHandleResult == 2r010.
	anOpenFile upToEnd.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but readable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin reading data based on having received this initial signal."
	sema wait. "consume the signal"

	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self deny: sema isSignaled. "handler has not been reset"]
		ensure:
			[[anOpenFile close] on: Error do: [].
			Smalltalk unregisterExternalObject: sema.
			(fileHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: fileHandle]]
]

{ #category : #testing }
AioEventHandlerTestCase >> testFileWritableEvent [

	| eventHandler anOpenFile fileHandle aioHandleResult sema semaIndex aioEnableResult fileName |
	fileName := 'DeleteThisTemporaryFile'.

	eventHandler := AioEventHandler new.
	OSProcess deleteFileNamed: fileName.
	[anOpenFile := OSProcess fileNamed: fileName.
	fileHandle := eventHandler handleForFile: anOpenFile.
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	[aioEnableResult := eventHandler
			aioEnable: fileHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].
	self assert: semaIndex == aioEnableResult.

	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: false
		writeEvents: true.
	self assert: aioHandleResult == 2r0100.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but writable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin writing data based on having received this initial signal."
	sema wait. "consume the signal"
	self deny: sema isSignaled.

	"Reset handler"
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: false
		writeEvents: true.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but writable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin writing data based on having received this initial signal."
	sema wait. "consume the signal"
	self deny: sema isSignaled.

	"Reset handler"
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: false
		writeEvents: true.
	anOpenFile upToEnd.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but writable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin writing data based on having received this initial signal."
	sema wait. "consume the signal"
	self deny: sema isSignaled.

	"Reset handler"
	aioHandleResult := eventHandler
		aioHandle: fileHandle
		exceptionEvents: false
		readEvents: false
		writeEvents: true.
	anOpenFile nextPutAll: 'write some stuff to the file'; flush.
	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self assert: sema isSignaled. "File is empty but writable. A signal is sent once,
	presumably in the interest of priming the pump. A listening process would
	begin writing data based on having received this initial signal."
	sema wait. "consume the signal"
	self deny: sema isSignaled.

	(Delay forMilliseconds: 20) wait. "Allow signals to be handled"
	self deny: sema isSignaled. "handler has not been reset"]
		ensure:
			[[anOpenFile close] on: Error do: [].
			Smalltalk unregisterExternalObject: sema.
			(fileHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: fileHandle]]
]

{ #category : #testing }
AioEventHandlerTestCase >> testHandleForFile [

	| eventHandler anOpenFile fileHandle |
	eventHandler := AioEventHandler new.
	anOpenFile := OSProcess fileNamed: 'delete.me'.
	fileHandle := eventHandler handleForFile: anOpenFile.
	anOpenFile close.
	OSProcess deleteFileNamed: 'delete.me'.
	self assert: fileHandle notNil.
	self assert: (fileHandle isKindOf: Integer)

]

{ #category : #testing }
AioEventHandlerTestCase >> testHandleForSocket [

	| eventHandler socket socketHandle |
	eventHandler := AioEventHandler new.
	socket := Socket newTCP.
	socketHandle := eventHandler handleForSocket: socket.
	self assert: socketHandle notNil.
	self assert: (socketHandle isKindOf: Integer).
	self assert: (socketHandle ~= 0) "0 is stdin on unix, unlikely to be used on other platforms"

]

{ #category : #testing }
AioEventHandlerTestCase >> testPrimAioModuleName [

	| eventHandler moduleName |
	eventHandler := AioEventHandler new.
	moduleName := eventHandler primAioModuleName.
	self assert: ('AioPlugin*' match: moduleName)

]

{ #category : #testing }
AioEventHandlerTestCase >> testPrimAioModuleVersionString [

	| eventHandler versionString |
	eventHandler := AioEventHandler new.
	versionString := eventHandler primAioModuleName.
	self assert: (versionString isKindOf: String)

]

{ #category : #testing }
AioEventHandlerTestCase >> testSocketExceptionEvent [
	"Close the client socket to generate an event on the server socket"

	| port serverName serverTcpSocket clientTcpSocket sema semaIndex socketHandle eventHandler receivedData |
	port := 8086.
	serverName := '127.0.0.1'.
	Socket initializeNetwork.

	"Create the server (reader) socket"
	serverTcpSocket := Socket newTCP.
	serverTcpSocket listenOn: port.

	"Create the client (writer) socket"
	clientTcpSocket := Socket newTCP.
	clientTcpSocket connectTo: (NetNameResolver addressFromString: serverName) port: port.

	"Esstablish socket connection"
	[serverTcpSocket waitForConnectionFor: 10] fork.
	clientTcpSocket waitForConnectionFor: 10.

	["Set up a read event handler on the server socket"
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	eventHandler := AioEventHandler new.
	socketHandle := eventHandler handleForSocket: serverTcpSocket.

	"An aio handler may already have been established for the socket
	by the SocketPlugin. The following request disables any existing handling
	in order to prevent a warning message on the console stderr."
	eventHandler aioDisable: socketHandle.

	"Now set our own handler."
	[eventHandler
			aioEnable: socketHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].
	eventHandler
		aioHandle: socketHandle
		exceptionEvents: true
		readEvents: false
		writeEvents: false.
	self deny: sema isSignaled.
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	self deny: sema isSignaled.
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.
	self deny: sema isSignaled.
	receivedData := serverTcpSocket receiveAvailableData.
	clientTcpSocket close.
	(Delay forMilliseconds: 200) wait.
	receivedData := serverTcpSocket receiveAvailableData.
	(Delay forMilliseconds: 200) wait.
"	self assert: sema isSignaled.	FIXME: no error generated; need to find a way to generate an error -dtl"
	self deny: sema isSignaled.
	serverTcpSocket close]
		ensure:
			[Smalltalk unregisterExternalObject: sema.
			(socketHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: socketHandle]]
]

{ #category : #testing }
AioEventHandlerTestCase >> testSocketExceptionEvent2 [
	"Close the client socket to generate an event on the server socket"

	| port serverTcpSocket sema semaIndex socketHandle eventHandler |
	port := 8086.
	Socket initializeNetwork.

	"Create the server (reader) socket"
	serverTcpSocket := Socket newTCP.
	serverTcpSocket listenOn: port.

	["Set up an exception event handler on the server socket"
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	eventHandler := AioEventHandler new.
	socketHandle := eventHandler handleForSocket: serverTcpSocket.

	"An aio handler may already have been established for the socket
	by the SocketPlugin. The following request disables any existing handling
	in order to prevent a warning message on the console stderr."
	eventHandler aioDisable: socketHandle.

	"Now set our own handler."
	[eventHandler
			aioEnable: socketHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].
	eventHandler
		aioHandle: socketHandle
		exceptionEvents: true
		readEvents: false
		writeEvents: true.
	self deny: sema isSignaled.
	[serverTcpSocket
		primSocket: serverTcpSocket socketHandle
		sendData: 'a string to send'
		startIndex: 1
		count: 10] on: Error do: [self halt].
	serverTcpSocket
		receiveSomeDataInto: (String new: 1000)
		startingAt: 1.

"	self assert: sema isSignaled.	FIXME: no error generated; need to find a way to generate an error -dtl"
	self deny: sema isSignaled.

	serverTcpSocket close]
		ensure:
			[Smalltalk unregisterExternalObject: sema.
			(socketHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: socketHandle]]
]

{ #category : #testing }
AioEventHandlerTestCase >> testSocketReadableEvent [

	| port serverName serverTcpSocket clientTcpSocket sema semaIndex socketHandle eventHandler receivedData |
	port := 8086.
	serverName := '127.0.0.1'.
	Socket initializeNetwork.

	"Create the server (reader) socket"
	serverTcpSocket := Socket newTCP.
	serverTcpSocket listenOn: port.

	"Create the client (writer) socket"
	clientTcpSocket := Socket newTCP.
	clientTcpSocket connectTo: (NetNameResolver addressFromString: serverName) port: port.

	"Establish socket connection"
	[serverTcpSocket waitForConnectionFor: 10] fork.
	clientTcpSocket waitForConnectionFor: 10.

	["Set up a read event handler on the server socket"
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	eventHandler := AioEventHandler new.
	socketHandle := eventHandler handleForSocket: serverTcpSocket.

	"An aio handler may already have been established for the socket
	by the SocketPlugin. The following request disables any existing handling
	in order to prevent a warning message on the console stderr."
	eventHandler aioDisable: socketHandle.

	"Now set our own handler."
	[eventHandler
			aioEnable: socketHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].

	eventHandler
		aioHandle: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	self deny: sema isSignaled.
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	self assert: sema isSignaled.
	sema wait. "consume the signal"
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.

	eventHandler
		aioHandle: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	self deny: sema isSignaled.
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	self assert: sema isSignaled.
	sema wait. "consume the signal"
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.

	eventHandler
		aioHandle: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	self deny: sema isSignaled.
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	self assert: sema isSignaled.
	sema wait. "consume the signal"
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.

	clientTcpSocket close.
	serverTcpSocket close]
		ensure:
			[Smalltalk unregisterExternalObject: sema.
			(socketHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: socketHandle]]
]

{ #category : #testing }
AioEventHandlerTestCase >> testSocketReadableEventWithMaskNotSet [
	"Same as testSocketReadableEvent, except that the mask bit for read events is not set,
	so we expect to not receive the event notification. This is just a check to ensure that
	the event mask is working."

	| port serverName serverTcpSocket clientTcpSocket sema semaIndex socketHandle eventHandler receivedData |
	port := 8086.
	serverName := '127.0.0.1'.
	Socket initializeNetwork.

	"Create the server (reader) socket"
	serverTcpSocket := Socket newTCP.
	serverTcpSocket listenOn: port.

	"Create the client (writer) socket"
	clientTcpSocket := Socket newTCP.
	clientTcpSocket connectTo: (NetNameResolver addressFromString: serverName) port: port.

	"Establish socket connection"
	[serverTcpSocket waitForConnectionFor: 10] fork.
	clientTcpSocket waitForConnectionFor: 10.

	["Set up a read event handler on the server socket"
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	eventHandler := AioEventHandler new.
	socketHandle := eventHandler handleForSocket: serverTcpSocket.

	"An aio handler may already have been established for the socket
	by the SocketPlugin. The following request disables any existing handling
	in order to prevent a warning message on the console stderr."
	eventHandler aioDisable: socketHandle.

	"Now set our own handler."
	[eventHandler
			aioEnable: socketHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].
	eventHandler
		aioHandle: socketHandle
		exceptionEvents: true
		readEvents: false	"Read event bit not set"
		writeEvents: false.
	self deny: sema isSignaled.
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	self deny: sema isSignaled. "This time we should not receive a signal"
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.
	clientTcpSocket close.
	serverTcpSocket close]
		ensure:
			[Smalltalk unregisterExternalObject: sema.
			(socketHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: socketHandle]]
]

{ #category : #testing }
AioEventHandlerTestCase >> testSuspendAioForSocketReadableEvent [

	| port serverName serverTcpSocket clientTcpSocket sema semaIndex socketHandle eventHandler receivedData |
	port := 8086.
	serverName := '127.0.0.1'.
	Socket initializeNetwork.

	"Create the server (reader) socket"
	serverTcpSocket := Socket newTCP.
	serverTcpSocket listenOn: port.

	"Create the client (writer) socket"
	clientTcpSocket := Socket newTCP.
	clientTcpSocket connectTo: (NetNameResolver addressFromString: serverName) port: port.

	"Establish socket connection"
	[serverTcpSocket waitForConnectionFor: 10] fork.
	clientTcpSocket waitForConnectionFor: 10.

	["Set up a read event handler on the server socket"
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	eventHandler := AioEventHandler new.
	socketHandle := eventHandler handleForSocket: serverTcpSocket.

	"An aio handler may already have been established for the socket
	by the SocketPlugin. The following request disables any existing handling
	in order to prevent a warning message on the console stderr."
	eventHandler aioDisable: socketHandle.

	"Now set our own handler."
	[eventHandler
			aioEnable: socketHandle
			forSemaphore: semaIndex
			externalObject: true]
		on: Warning
		do: ["Suppress warning dialog. Unit test will fail next assert."].

	eventHandler
		aioHandle: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.

	self deny: sema isSignaled.

	"Handler generates a signal"
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.
	self assert: sema isSignaled.
	sema wait.
	self deny: sema isSignaled.

	"Handler has not been reset, so no signal this time"
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.
	self deny: sema isSignaled.

	"Reset the handler"
	eventHandler
		aioHandle: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.

	"Handler generates a signal"
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.
	self assert: sema isSignaled.
	sema wait.
	self deny: sema isSignaled.

	"Reset the handler"
	eventHandler
		aioHandle: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.
	"But temporarily disable it"
	eventHandler aioSuspend: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.

	"Handler suspended, so no signal this time"
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.
	self deny: sema isSignaled.

	"Reset the handler"
	eventHandler
		aioHandle: socketHandle
		exceptionEvents: false
		readEvents: true
		writeEvents: false.

	"Handler generates a signal"
	clientTcpSocket sendData: 'some data to send to the socket'.
	(Delay forMilliseconds: 200) wait.
	receivedData := serverTcpSocket receiveAvailableData.
	self assert: 'some data to send to the socket' = receivedData.
	self assert: sema isSignaled.
	sema wait.
	self deny: sema isSignaled.

	clientTcpSocket close.
	serverTcpSocket close]
		ensure:
			[Smalltalk unregisterExternalObject: sema.
			(socketHandle isKindOf: Integer) ifTrue: [eventHandler aioDisable: socketHandle]]
]
