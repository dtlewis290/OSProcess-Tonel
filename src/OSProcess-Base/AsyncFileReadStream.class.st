"
AsyncFileReadStream implements event-driven read behavior on a file stream. Whenever data is available, a #changed event is generated. An AsyncFileReadStream expects to have a client object respond immediately to the change notification by reading the available data, otherwise a possibly endless stream of change notifications will be generated.

AsyncFileReadStream requires aio support in the AioPlugin module.
"
Class {
	#name : #AsyncFileReadStream,
	#superclass : #AttachableFileStream,
	#instVars : [
		'eventHandler'
	],
	#category : #'OSProcess-Base'
}

{ #category : #examples }
AsyncFileReadStream class >> stdIn [

	"self stdIn"

	^ super stdIn initialize

]

{ #category : #finalization }
AsyncFileReadStream >> actAsExecutor [

	super actAsExecutor.
	eventHandler := nil
]

{ #category : #converting }
AsyncFileReadStream >> asAsyncFileReadStream [

	^ self

]

{ #category : #converting }
AsyncFileReadStream >> asAttachableFileStream [
	"Answer a replacement for this object, with no asynchronous event handling.
	Do not close the ioHandle when this object is finalized."

	self keepOpen.
	^ AttachableFileStream
		name: self name
		attachTo: self ioHandle
		writable: self isReadOnly not

]

{ #category : #converting }
AsyncFileReadStream >> asBufferedAsyncFileReadStream [
	"Answer a replacement for this object, with buffered output."

	^ BufferedAsyncFileReadStream
		name: self name
		attachTo: self ioHandle
		writable: self isReadOnly not

]

{ #category : #'initialize-release' }
AsyncFileReadStream >> close [

	self disableEventHandling.
	^ super close
]

{ #category : #'read event handling' }
AsyncFileReadStream >> disableEventHandling [

	eventHandler
		ifNotNil: [eventHandler removeDependent: self; close].
	self eventHandler: nil
]

{ #category : #'read event handling' }
AsyncFileReadStream >> enableEventHandling [

	self eventHandler: (AioEventHandler aioPluginPresent
		ifTrue: [AioEventHandler
				forFileStream: self
				exceptions: true
				readEvents: true
				writeEvents: false]
		ifFalse: [PseudoAioEventHandler new]).
	self eventHandler addDependent: self
]

{ #category : #accessing }
AsyncFileReadStream >> eventHandler [
	"The aio event handler. Provides notification whenever external data is available."

	^ eventHandler
]

{ #category : #accessing }
AsyncFileReadStream >> eventHandler: anAioEventHandler [
	"The aio event handler. Provides notification whenever external data is available."

	eventHandler := anAioEventHandler
]

{ #category : #finalization }
AsyncFileReadStream >> finalize [
	"Shut the the event handler before closing the file, otherwise aio
	functions may reference a closed file handle."

	eventHandler ifNotNil: [eventHandler finalize].
	super finalize

]

{ #category : #'read event handling' }
AsyncFileReadStream >> hasValidHandler [

	^ self eventHandler notNil and: [eventHandler hasValidHandler]

]

{ #category : #'initialize-release' }
AsyncFileReadStream >> initialize [

	super initialize.
	self readOnly.
	OSProcess accessor setNonBlocking: self ioHandle.
	self enableEventHandling

]

{ #category : #'initialize-release' }
AsyncFileReadStream >> open [

	^ super open initialize

]

{ #category : #'read, write, position' }
AsyncFileReadStream >> upToEndOfFile [
	"Answer a subcollection from the current access position through
	the last element of the receiver.  Use #atEndOfFile to determine end
	of file status with feof(), required for reliable end of file test on
	OS pipes. Close the file when end of file is detected."

	| b |
	b := super upToEndOfFile.
	self isReadOnly
		ifTrue: [self close].
	^ b
]

{ #category : #updating }
AsyncFileReadStream >> update: aParameter [

	(aParameter == self eventHandler)
		ifTrue: [self changed]

]
