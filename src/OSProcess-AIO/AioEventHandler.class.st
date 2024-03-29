"
AioEventHandler responds to external IO events, such as data available on a file descriptor. When an external IO event is received, an instance of AioEventHandler sends #changed to itself to notify its dependents that the event has occurred.
"
Class {
	#name : #AioEventHandler,
	#superclass : #Model,
	#instVars : [
		'semaphore',
		'semaIndex',
		'handlerProc',
		'descriptor'
	],
	#classVars : [
		'AioPluginPresent'
	],
	#category : 'OSProcess-AIO'
}

{ #category : #testing }
AioEventHandler class >> aioPluginPresent [
	"Answer true if an AIO plugin is available. The value of AioPluginPresent
	is cleared at startup time, and is reestablished once for each Squeak session.
	See initializeAioPluginPresent to initialize after an image startup if warning
	dialog is not desired."

	"AioEventHandler aioPluginPresent"

	^ AioPluginPresent
		ifNil: [AioPluginPresent := self basicNew primAioModuleVersionString notNil.
			AioPluginPresent ifFalse:
				[OSProcess trace: ' AioPlugin not present, AioEventHandler will use polling input'].
			^ AioPluginPresent]
]

{ #category : #'instance creation' }
AioEventHandler class >> for: aSocketOrFileStream [

	"self for: SourceFiles first"
	"self for: Socket new"
	"self for: OSProcess thisOSProcess stdIn"

	^ self new for: aSocketOrFileStream
]

{ #category : #'instance creation' }
AioEventHandler class >> for: aSocketOrFileStream exceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [
	"Flag parameters are true or false, indicating types of events to be handled."

	^ self new for: aSocketOrFileStream
			exceptions: exceptionEventFlag
			readEvents: readEventFlag
			writeEvents: writeEventFlag
]

{ #category : #'instance creation' }
AioEventHandler class >> forFileStream: aFileStream [

	"self forFileStream: SourceFiles first"

	^ self new forFileStream: aFileStream


]

{ #category : #'instance creation' }
AioEventHandler class >> forFileStream: aFileStream exceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [
	"Flag parameters are true or false, indicating types of events to be handled."

	"self forFileStream: SourceFiles first"

	^ self new forFileStream: aFileStream
			exceptions: exceptionEventFlag
			readEvents: readEventFlag
			writeEvents: writeEventFlag

]

{ #category : #'instance creation' }
AioEventHandler class >> forSocket: aSocket [

	"self forSocket: Socket new"

	^ self new forSocket: aSocket


]

{ #category : #'instance creation' }
AioEventHandler class >> forSocket: aSocket exceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [
	"Flag parameters are true or false, indicating types of events to be handled."

	"self forSocket: Socket new"

	^ self new forSocket: aSocket
			exceptions: exceptionEventFlag
			readEvents: readEventFlag
			writeEvents: writeEventFlag

]

{ #category : #testing }
AioEventHandler class >> initializeAioPluginPresent [
	"Initialize the AioPluginPresent flag silently without invoking a warning
	if the plugin is not present, and answer the value of the flag. Send this
	to prevent a warning dialog from being presented after image startup,
	as may be preferred if the image is to be run headless."

	"AioEventHandler initializeAioPluginPresent"

	^ AioPluginPresent
		ifNil: [AioPluginPresent := self basicNew primAioModuleVersionString notNil]
]

{ #category : #'system startup' }
AioEventHandler class >> startUp: resuming [
	"Clear the value of AioPluginPresent. The value will be set once when
	#aioPluginPresent is first sent, and will remain set to that value for the
	duration of this Squeak session.
	This method is called by ThisOSProcess>>startUp. AioEventHandler does
	not need to be registered in the system startup list."

	resuming ifTrue: [AioPluginPresent := nil]

]

{ #category : #'aio event forwarding' }
AioEventHandler >> aioDisable: ioDescriptor [
	"Definitively disable asynchronous event notification for a descriptor. The ioDescriptor
	parameter is an object representing a low level OS file or socket descriptor."

	^ self primAioDisable: ioDescriptor

]

{ #category : #'aio event forwarding' }
AioEventHandler >> aioEnable: ioDescriptor forSemaphore: semaphoreIndex externalObject: trueOrFalse [
	"Enable asynchronous notification for a descriptor. Send this message one time
	prior to beginning event handling for ioDescriptor. The ioDescriptor parameter is an
	object representing a low level OS file or socket descriptor. The semaphoreIndex is
	the index of a Semaphore to be notified, and the third parameter is a flag indicating
	that ioDescriptor represents an external object which should not be closed on termination
	of aio handling."

	^ (self primAioEnable: ioDescriptor forSemaphore: semaphoreIndex externalObject: trueOrFalse)
			ifNil: [self notify: 'aio event forwarding not supported']

]

{ #category : #'aio event forwarding' }
AioEventHandler >> aioHandle: ioDescriptor exceptionEvents: exceptionFlag readEvents: readFlag writeEvents: writeFlag [
	"Enable asynchronous notification for a descriptor. Send this message one time to
	enable a single event notification. Send it again after each event has been received
	and handled (in other words, the process which waits on the event semaphore is
	responsible for re-enabling the handler by calling this method each time an event
	is handled). The ioDescriptor parameter is an object representing a low level OS file or
	socket descriptor. The remaining three parameters are Boolean flags representing the
	types of events for which notification is being requested: handle exceptions, handle
	for read, and handle for write. It is common to watch for read events and exception
	events, or to watch for write events and exception events."

	^ self primAioHandle: ioDescriptor
		exceptionEvents: exceptionFlag
		readEvents: readFlag
		writeEvents: writeFlag

]

{ #category : #'aio event forwarding' }
AioEventHandler >> aioSuspend: ioDescriptor exceptionEvents: exceptionFlag readEvents: readFlag writeEvents: writeFlag [

	"Temporarily suspend asynchronous event notification for a descriptor. The
	ioDescriptor parameter is an object representing a low level OS file or socket
	descriptor. The remaining three parameters are Boolean flags representing the
	types of events for which notification is being requested: handle exceptions,
	handle for read, and handle for write."

	^ self primAioSuspend: ioDescriptor
		exceptionEvents: exceptionFlag
		readEvents: readFlag
		writeEvents: writeFlag

]

{ #category : #'initialize-release' }
AioEventHandler >> close [
	"When the FileStream or Socket handled by this aio handler is closed,
	it should send #close to this handler."

	| p |
	self breakDependents.
	Smalltalk unregisterExternalObject: semaphore.
	self aioDisable: self descriptor.
	semaphore := nil.
	semaIndex := nil.
	p := handlerProc.
	handlerProc := nil.
	p ifNotNil: [p terminate] "p may be the active process, do this last"

]

{ #category : #'handler process' }
AioEventHandler >> defaultHandlerProcess [
	"Generate a #changed notification whenever an external aio event occurs"

	^ self handleReadAndExceptionsEvents
]

{ #category : #accessing }
AioEventHandler >> descriptor [

	^ descriptor
]

{ #category : #accessing }
AioEventHandler >> descriptor: aLowLevelIODescriptor [

	descriptor := aLowLevelIODescriptor
]

{ #category : #finalization }
AioEventHandler >> finalize [
	"Note: An aio handler will not be garbage collected until the semaphore
	is unregistered. When the FileStream or Socket handled by this aio
	handler is closed, it should send #close to this handler."

	self close

]

{ #category : #'initialize-release' }
AioEventHandler >> for: aSocketOrFileStream [
	"Answer an event handler for any kind of IO stream that can be associated
	with an OS handle for aio events. Currently, subclasses of FileStream and
	Socket can have aio event handlers."

	(aSocketOrFileStream isKindOf: Socket)
		ifTrue: [^ self forSocket: aSocketOrFileStream].
	(aSocketOrFileStream isKindOf: FileStream)
		ifTrue: [^ self forFileStream: aSocketOrFileStream].
	self error: 'expected a FileStream or Socket subclass'
]

{ #category : #'initialize-release' }
AioEventHandler >> for: aSocketOrFileStream exceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [
	"Answer an event handler for any kind of IO stream that can be associated
	with an OS handle for aio events. Currently, subclasses of FileStream and
	Socket can have aio event handlers."

	(aSocketOrFileStream isKindOf: Socket)
		ifTrue: [^ self forSocket: aSocketOrFileStream
					exceptions: exceptionEventFlag
					readEvents: readEventFlag
					writeEvents: writeEventFlag].
	(aSocketOrFileStream isKindOf: FileStream)
		ifTrue: [^ self forFileStream: aSocketOrFileStream
					exceptions: exceptionEventFlag
					readEvents: readEventFlag
					writeEvents: writeEventFlag].
	self error: 'expected a FileStream or Socket subclass'
]

{ #category : #'initialize-release' }
AioEventHandler >> forFileStream: aFileStream [

	self descriptor: (self handleForFile: aFileStream).
	self setDefaultEventMask.

]

{ #category : #'initialize-release' }
AioEventHandler >> forFileStream: aFileStream exceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [

	self descriptor: (self handleForFile: aFileStream).
	self initializeForExceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag


]

{ #category : #'initialize-release' }
AioEventHandler >> forSocket: aSocket [
	"Any existing event handling for aSocket will be disabled. Note that this
	will make the socket useless for any applications that expect the prior
	event handling behavior."

	self descriptor: (self handleForSocket: aSocket).
	self aioDisable: self descriptor.
	self setDefaultEventMask.

]

{ #category : #'initialize-release' }
AioEventHandler >> forSocket: aSocket exceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [
	"Any existing event handling for aSocket will be disabled. Note that this
	will make the socket useless for any applications that expect the prior
	event handling behavior."

	self descriptor: (self handleForSocket: aSocket).
	self aioDisable: self descriptor.
	self initializeForExceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag

]

{ #category : #'handler process' }
AioEventHandler >> handleExceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [
	"Generate a #changed notification whenever the requested type of external aio event occurs."

	| p sema handler |
	sema := Semaphore new.
	handler := [[self hasValidHandler] whileTrue:
		[self aioHandle: self descriptor
			exceptionEvents: exceptionEventFlag
			readEvents: readEventFlag
			writeEvents: writeEventFlag.
		sema signal. "event handler is ready"
		self semaphore wait.
		self changed]].
	p := handler forkAt: Processor userBackgroundPriority.
	sema wait. "until process has been started and events are being handled"
	^p
]

{ #category : #private }
AioEventHandler >> handleForFile: aFileStream [

	"self new handleForFile: SourceFiles first"

	| ioHandle |
	ioHandle := self useIOHandle
		ifTrue: [aFileStream ioHandle]
		ifFalse: [aFileStream fileID].
	^ self primOSFileHandle: ioHandle

]

{ #category : #private }
AioEventHandler >> handleForSocket: aSocket [

	"self new handleForSocket: Socket newTCP"

	| ioHandle |
	ioHandle := self useIOHandle
		ifTrue: [aSocket ioHandle]
		ifFalse: [aSocket socketHandle].
	^ self primOSSocketHandle: ioHandle

]

{ #category : #'handler process' }
AioEventHandler >> handleReadAndExceptionsEvents [
	"Generate a #changed notification whenever data is available for reading or an exception
	occurs on the external IO channel."

	^ self handleExceptions: true readEvents: true writeEvents: false

]

{ #category : #'handler process' }
AioEventHandler >> handleReadEvents [
	"Generate a #changed notification whenever data is available for reading"

	^ self handleExceptions: false readEvents: true writeEvents: false

]

{ #category : #accessing }
AioEventHandler >> handlerProc [

	^ handlerProc
]

{ #category : #'handler process' }
AioEventHandler >> hasValidHandler [
	"True if the event handler is running, and if it refers to the correct external
	object semaphore. For protection following an image restart."

	^ semaIndex notNil
		and: [Smalltalk externalObjects size >= semaIndex
			and: [(Smalltalk externalObjects at: semaIndex) == semaphore]]
]

{ #category : #'initialize-release' }
AioEventHandler >> initializeForExceptions: exceptionEventFlag readEvents: readEventFlag writeEvents: writeEventFlag [

	semaphore := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: semaphore.
	(AioPluginPresent = true) ifTrue: [
		([self aioEnable: self descriptor forSemaphore: self semaIndex externalObject: true]
			on: Warning
			do: [:e |
				self close. "unregister the semaphore"
				OSProcess trace: e messageText asString. nil])
			ifNotNil:
				[handlerProc := self
					handleExceptions: exceptionEventFlag
					readEvents: readEventFlag
					writeEvents: writeEventFlag]]

]

{ #category : #'primitive access' }
AioEventHandler >> primAioDisable: aDescriptor [
	"Definitively disable asynchronous event notification for a descriptor. The descriptor
	parameter is an object representing a low level OS file or socket descriptor."

	<primitive: 'primitiveAioDisable' module: 'AioPlugin'>
	^ nil

]

{ #category : #'primitive access' }
AioEventHandler >> primAioEnable: aDescriptor forSemaphore: semaphoreIndex externalObject: trueOrFalse [
	"Enable asynchronous notification for a descriptor. The descriptor parameter is an
	object representing a low level OS file or socket descriptor. The semaphoreIndex
	is the index of a Semaphore to be notified, and the third parameter is a flag indicating
	that descriptor represents an external object which should not be closed on termination
	of aio handling."

	<primitive: 'primitiveAioEnable' module: 'AioPlugin'>
	^ nil

]

{ #category : #'primitive access' }
AioEventHandler >> primAioHandle: aDescriptor exceptionEvents: exceptionFlag readEvents: readFlag writeEvents: writeFlag [
	"Enable asynchronous notification for a descriptor. The descriptor parameter is an
	object representing a low level OS file or socket descriptor. The second parameter is
	the index of a Semaphore to be notified, the remaining three parameters are Boolean
	flags representing the types of events for which notification is being requested:
	handle exceptions, handle for read, and handle for write. It is common to watch for
	read events and exception events, or to watch for write events and exception events."

	<primitive: 'primitiveAioHandle' module: 'AioPlugin'>
	^ nil

]

{ #category : #'primitive access' }
AioEventHandler >> primAioModuleName [
	"Module name of the installed plugin, if any."

	"self new primAioModuleName"

	<primitive: 'primitiveModuleName' module: 'AioPlugin'>
	^ nil

]

{ #category : #'primitive access' }
AioEventHandler >> primAioModuleVersionString [
	"Module name of the installed plugin, if any."

	"self new primAioModuleVersionString"

	<primitive: 'primitiveVersionString' module: 'AioPlugin'>
	^ nil

]

{ #category : #'primitive access' }
AioEventHandler >> primAioSuspend: aDescriptor exceptionEvents: exceptionFlag readEvents: readFlag writeEvents: writeFlag [
	"Temporarily suspend asynchronous event notification for a descriptor. The
	descriptor parameter is an object representing a low level OS file or socket
	descriptor. The remaining three parameters are Boolean flags representing the
	types of events for which notification is being requested: handle exceptions,
	handle for read, and handle for write."

	<primitive: 'primitiveAioSuspend' module: 'AioPlugin'>
	^ nil

]

{ #category : #'primitive access' }
AioEventHandler >> primOSFileHandle: sqFile [
	"Answer the low level file descriptor for a file IO handle."

	<primitive: 'primitiveOSFileHandle' module: 'AioPlugin'>
	^ nil

]

{ #category : #'primitive access' }
AioEventHandler >> primOSSocketHandle: sqFile [
	"Answer the low level socket descriptor for a socket IO handle."

	<primitive: 'primitiveOSSocketHandle' module: 'AioPlugin'>
	^ nil

]

{ #category : #accessing }
AioEventHandler >> semaIndex [

	^ semaIndex
]

{ #category : #accessing }
AioEventHandler >> semaphore [

	^ semaphore
]

{ #category : #'initialize-release' }
AioEventHandler >> setDefaultEventMask [
	"Default initialization for read events and exception events"

	^ self initializeForExceptions: true readEvents: true writeEvents: false


]

{ #category : #private }
AioEventHandler >> useIOHandle [

	^ Smalltalk hasClassNamed: #IOHandle
]
