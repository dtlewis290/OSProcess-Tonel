"
I represent a pipe provided by the underlying operating system, such as a Unix pipe. I have a reader stream and a writer stream which behave similarly to a read-only FileStream and a writeable FileStream.

Subclasses implement buffering behavior for the reader end of a pipe.
"
Class {
	#name : #ExternalPipe,
	#superclass : #Stream,
	#instVars : [
		'writer',
		'reader',
		'blocking'
	],
	#category : #'OSProcess-Base'
}

{ #category : #'instance creation' }
ExternalPipe class >> blockingPipe [
	"Warning: a read on a blocking pipe will hang the VM if there is insufficient
	data in the pipe to fulfill the read request."

	"OSPipe blockingPipe"

	^ super basicNew initialize; setBlocking

]

{ #category : #'instance creation' }
ExternalPipe class >> bufferedBlockingPipe [
	"Warning: a read on a blocking pipe will hang the VM if there is insufficient
	data in the pipe to fulfill the read request."

	"OSPipe bufferedBlockingPipe"

	^ (super basicNew initialize; setBlocking) setBufferedReader; yourself

]

{ #category : #'instance creation' }
ExternalPipe class >> bufferedNonBlockingPipe [

	"OSPipe bufferedNonBlockingPipe"

	^ (super basicNew initialize; setNonBlocking) setBufferedReader; yourself

]

{ #category : #'instance creation' }
ExternalPipe class >> new [

	"ExternalPipe new"

	^ self nonBlockingPipe

]

{ #category : #'instance creation' }
ExternalPipe class >> nonBlockingPipe [

	"OSPipe nonBlockingPipe"

	^ super basicNew initialize; setNonBlocking

]

{ #category : #examples }
ExternalPipe class >> testPipe [
	"OSPipe testPipe inspect"

	| pipe result |
	pipe _ self new.
	pipe nextPutAll: 'string to send through an OSPipe'.
	pipe writer close.
	result _ pipe upToEnd.
	pipe close.
	^ result

]

{ #category : #testing }
ExternalPipe >> atEnd [
	"Answer whether the receiver can access any more objects."

	^ writer closed and: [self peek == nil]

]

{ #category : #accessing }
ExternalPipe >> blocking [
	"True if reader end is set to blocking mode."

	^ blocking ifNil: [blocking _ true]
]

{ #category : #accessing }
ExternalPipe >> blocking: trueOrFalse [
	"True if reader end is set to blocking mode."

	blocking _ trueOrFalse
]

{ #category : #finalization }
ExternalPipe >> close [

	self closeWriter; closeReader

]

{ #category : #finalization }
ExternalPipe >> closeReader [

	reader ifNotNil: [reader close]

]

{ #category : #finalization }
ExternalPipe >> closeWriter [

	writer ifNotNil: [writer close]

]

{ #category : #testing }
ExternalPipe >> closed [

	^ reader closed
]

{ #category : #accessing }
ExternalPipe >> contents [
	"Answer contents of the pipe, and return the contents to the pipe so it can still be read."

	"ExternalPipe new nextPutAll: 'hello'; contents"

	| s |
	self closed ifTrue:
		[self notify: self printString, ' ', self reader printString, ' closed'.
		^ nil].
	s _ self reader upToEnd.
	s isEmpty ifFalse:
		[self writer closed
			ifTrue: [self notify: self printString, ' ', self writer printString,
								' closed, cannot replace contents']
			ifFalse: [self nextPutAll: s]].
	^ s
]

{ #category : #'character writing' }
ExternalPipe >> cr [
	"Append a return character to the receiver."

	self writer cr
]

{ #category : #finalization }
ExternalPipe >> finalize [

	self close.
	^ super finalize

]

{ #category : #'initialize-release' }
ExternalPipe >> initialize [

	^ self makePipe

]

{ #category : #testing }
ExternalPipe >> isPipe [

	^ true

]

{ #category : #'initialize-release' }
ExternalPipe >> makePipe [
	"Create an OS pipe and attach it to my input and output streams."

	| handleArray |
	handleArray _ OSProcess accessor makePipeHandles.
	handleArray isNil
		ifTrue:
			[self error: 'cannot create OS pipe']
		ifFalse:
			[self reader: (AttachableFileStream
							name: 'pipeReader'
							attachTo: (handleArray at: 1)
							writable: false).
			self writer: (AttachableFileStream
							name: 'pipeWriter'
							attachTo: (handleArray at: 2)
							writable: true)]

]

{ #category : #accessing }
ExternalPipe >> next [
	"Answer the next object accessible by the receiver."

	^ reader next
]

{ #category : #accessing }
ExternalPipe >> next: anInteger [ 
	"Answer the next anInteger elements of my collection."

	^ reader next: anInteger

]

{ #category : #accessing }
ExternalPipe >> nextPut: anObject [ 
	"Insert the argument, anObject, as the next object accessible by the 
	receiver. Answer anObject."

	^ writer nextPut: anObject
]

{ #category : #accessing }
ExternalPipe >> nextPutAll: aCollection [ 
	"Append the elements of aCollection to the sequence of objects accessible 
	by the receiver. Answer aCollection."

	^ writer nextPutAll: aCollection
]

{ #category : #accessing }
ExternalPipe >> peek [

	^ reader peek
]

{ #category : #printing }
ExternalPipe >> printOn: aStream [
	"The implementation of Stream>>printOn: has bad side effects when used
	for OSPipe. This implementation is copied from Object."

	| title |
	title _ self class name.
	aStream
		nextPutAll: (title first isVowel ifTrue: ['an '] ifFalse: ['a ']);
		nextPutAll: title
]

{ #category : #accessing }
ExternalPipe >> reader [
	"Answer a stream on the read end of the pipe."

	^ reader
]

{ #category : #accessing }
ExternalPipe >> reader: aReadStream [

	reader _ aReadStream
]

{ #category : #finalization }
ExternalPipe >> registerFinalization [
	"Arrange for finalization at garbage collection time"

	self finalizationRegistry add: self

]

{ #category : #'initialize-release' }
ExternalPipe >> setBlocking [
	"Set the reader side of the pipe for blocking reads."

	reader ifNotNil: [OSProcess accessor setBlocking: reader ioHandle].
	self blocking: true

]

{ #category : #'initialize-release' }
ExternalPipe >> setBufferedReader [
	"Use an event driven AsyncFileReadStream to represent the reader end of the pipe.
	This should be used if the pipe will be read by a Smalltalk process. It should not
	be used if the pipe is to be read by an external OS process."

	reader ifNotNil:
		[reader removeDependent: self.
		reader unregister.
		self reader: reader asBufferedAsyncFileReadStream.
		self setNonBlocking.
		reader addDependent: self.
		^ true].
	^ false

]

{ #category : #'initialize-release' }
ExternalPipe >> setNonBlocking [
	"Set the reader side of the pipe for non-blocking reads."

	reader ifNotNil: [OSProcess accessor setNonBlocking: reader ioHandle].
	self blocking: false

]

{ #category : #testing }
ExternalPipe >> testEndOfFile [
	"Answer whether the receiver is at its end based on the result of
	the last read operation. This uses feof() to test the underlying file
	stream status, and can be used as an alternative to #atEnd, which
	does not properly report end of file status for an OSPipe."

	^ reader atEnd

]

{ #category : #updating }
ExternalPipe >> triggerDataReady [
	"Notify any object waiting for data ready on the pipe."

	self triggerEvent: #dataReady.

]

{ #category : #accessing }
ExternalPipe >> upToEnd [
	"Answer the remaining elements in the string"

	reader closed
		ifTrue: [^ '']
		ifFalse: [^ reader upToEnd]
]

{ #category : #updating }
ExternalPipe >> update: aParameter [
	"Notify any object waiting for data ready on the pipe."

	self changed.
	self triggerDataReady.
	^ super update: aParameter

]

{ #category : #accessing }
ExternalPipe >> writer [
	"Answer a stream on the write end of the pipe."

	^ writer
]

{ #category : #accessing }
ExternalPipe >> writer: aWriteStream [

	writer _ aWriteStream
]
