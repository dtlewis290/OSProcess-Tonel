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

	eventHandler ifNotNilDo: [:h | 
		h close.
		h removeDependent: self].
	self eventHandler: nil

]

{ #category : #'read event handling' }
AsyncFileReadStream >> enableEventHandling [

	self eventHandler: (AioEventHandler
				forFileStream: self
				exceptions: true
				readEvents: true
				writeEvents: false).
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

	eventHandler _ anAioEventHandler
]

{ #category : #'initialize-release' }
AsyncFileReadStream >> finalize [

	self disableEventHandling.
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

{ #category : #updating }
AsyncFileReadStream >> update: aParameter [

	(aParameter == self eventHandler)
		ifTrue: [self changed]

]
