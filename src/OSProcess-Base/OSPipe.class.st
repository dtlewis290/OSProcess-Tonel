"
I represent a pipe provided by the underlying operating system, such as a Unix pipe. I have a reader stream and a writer stream which behave similarly to a read-only FileStream and a writeable FileStream.
"
Class {
	#name : #OSPipe,
	#superclass : #Stream,
	#instVars : [
		'reader',
		'writer',
		'nextChar'
	],
	#category : #'OSProcess-Base'
}

{ #category : #'instance creation' }
OSPipe class >> blockingPipe [
	"Warning: a read on a blocking pipe will hang the VM if there is insufficient
	data in the pipe to fulfill the read request."

	"OSPipe blockingPipe"

	^ super basicNew initializeBlockingPipe

]

{ #category : #'instance creation' }
OSPipe class >> new [

	"OSPipe new"

	^ super basicNew initialize

]

{ #category : #'instance creation' }
OSPipe class >> nonBlockingPipe [

	"OSPipe nonBlockingPipe"

	^ super basicNew initializeNonBlockingPipe

]

{ #category : #examples }
OSPipe class >> testPipe [
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
OSPipe >> atEnd [
	"Answer whether the receiver can access any more objects."

	^ writer closed and: [self peek == nil]

]

{ #category : #finalization }
OSPipe >> close [

	self closeWriter; closeReader

]

{ #category : #finalization }
OSPipe >> closeReader [

	reader ifNotNil: [reader close]

]

{ #category : #finalization }
OSPipe >> closeWriter [

	writer ifNotNil: [writer close]

]

{ #category : #testing }
OSPipe >> closed [

	^ reader closed & writer closed
]

{ #category : #accessing }
OSPipe >> contents [
	"Answer contents of the pipe, and return the contents to the pipe so it can still be read."

	"OSPipe new nextPutAll: 'hello'; contents"

	| s |
	s _ self reader upToEnd.
	self nextPutAll: s.
	^ s
]

{ #category : #'character writing' }
OSPipe >> cr [
	"Append a return character to the receiver."

	self writer cr
]

{ #category : #finalization }
OSPipe >> finalize [

	self close.
	^ super finalize

]

{ #category : #'initialize-release' }
OSPipe >> initialize [

	^ self initializeNonBlockingPipe

]

{ #category : #'initialize-release' }
OSPipe >> initializeBlockingPipe [
	"Create an OS pipe and attach it to my input and output streams. Set the
	reader side of the pipe for blocking reads. Warning: reading on a blocking
	pipe will hang the Squeak VM if the pipe does not contain enough data
	to fulfill the read request."

	self makePipe

]

{ #category : #'initialize-release' }
OSPipe >> initializeNonBlockingPipe [
	"Create an OS pipe and attach it to my input and output streams. Set the
	reader side of the pipe for non-blocking reads."

	self makePipe.
	self setNonBlocking

]

{ #category : #'initialize-release' }
OSPipe >> makePipe [
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
OSPipe >> next [
	"Answer the next object accessible by the receiver."

	| c |
	nextChar isNil
		ifTrue:
			[^ [reader next]
				on: Error
				do: [nil]]
		ifFalse:
			[c _ nextChar.
			nextChar _ nil.
			^ c]

]

{ #category : #accessing }
OSPipe >> next: anInteger [ 
	"Answer the next anInteger elements of my collection."

	| c strm |
	strm _ WriteStream on: ''.
	(1 to: anInteger) do:
		[:index |
		c _ self next.
		c isNil
			ifTrue: [^ strm contents]	
			ifFalse: [strm nextPut: c. false]].
	^ strm contents

]

{ #category : #accessing }
OSPipe >> nextPut: anObject [ 
	"Insert the argument, anObject, as the next object accessible by the 
	receiver. Answer anObject."

	^ writer nextPut: anObject
]

{ #category : #accessing }
OSPipe >> nextPutAll: aCollection [ 
	"Append the elements of aCollection to the sequence of objects accessible 
	by the receiver. Answer aCollection."

	^ writer nextPutAll: aCollection
]

{ #category : #accessing }
OSPipe >> peek [

	^ nextChar isNil
		ifTrue: [nextChar _ reader next]
		ifFalse: [nextChar]
]

{ #category : #printing }
OSPipe >> printOn: aStream [
	"The implementation of Stream>>printOn: has bad side effects when used
	for OSPipe. This implementation is copied from Object."

	| title |
	title _ self class name.
	aStream
		nextPutAll: (title first isVowel ifTrue: ['an '] ifFalse: ['a ']);
		nextPutAll: title
]

{ #category : #accessing }
OSPipe >> reader [
	"Answer a stream on the read end of the pipe."

	^ reader
]

{ #category : #accessing }
OSPipe >> reader: aReadStream [

	reader _ aReadStream
]

{ #category : #'initialize-release' }
OSPipe >> setBlocking [
	"Set the reader side of the pipe for blocking reads."

	reader ifNotNil: [OSProcess accessor setBlocking: reader ioHandle]

]

{ #category : #'initialize-release' }
OSPipe >> setNonBlocking [
	"Set the reader side of the pipe for non-blocking reads."

	reader ifNotNil: [OSProcess accessor setNonBlocking: reader ioHandle]

]

{ #category : #accessing }
OSPipe >> upToEnd [
	"Answer the remaining elements in the string"

	| strm d c |
	strm _ WriteStream on: ''.
	d _ Delay forMilliseconds: 200.
	[(c _ self next) isNil and: [writer closed]]
		whileFalse:
			[c isNil
				ifTrue: [d wait]
				ifFalse: [strm nextPut: c]].
	^ strm contents
]

{ #category : #accessing }
OSPipe >> writer [
	"Answer a stream on the write end of the pipe."

	^ writer
]

{ #category : #accessing }
OSPipe >> writer: aWriteStream [

	writer _ aWriteStream
]
