"
I represent a pipe provided by the underlying operating system, such as a Unix pipe. I have a reader stream and a writer stream which behave similarly to a read-only FileStream and a writeable FileStream.

I use a single-character buffer to implement #peek without losing data from the external OS pipe.
"
Class {
	#name : #OSPipe,
	#superclass : #ExternalPipe,
	#instVars : [
		'nextChar'
	],
	#category : #'OSProcess-Base'
}

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
OSPipe >> peek [

	^ nextChar isNil
		ifTrue: [reader closed
				ifFalse: [nextChar _ reader next]]
		ifFalse: [nextChar]
]

{ #category : #accessing }
OSPipe >> upToEnd [
	"Answer the remaining elements in the string. This method is retained for backward
	compatibility with older versions of CommandShell."

	| strm s |
	strm _ WriteStream on: ''.
	[(s _ self next: 2000) isEmpty
		ifTrue: [^ strm contents]
		ifFalse: [strm nextPutAll: s]] repeat

]

{ #category : #accessing }
OSPipe >> upToEndOfFile [
	"Answer the remaining elements in the pipe. Use #atEndOfFile to
	determine end of file status with feof(), required for reliable end of
	file test on OS pipes. Compare #upToEnd, which uses the generic end
	of file test in FilePlugin."

	| strm d s |
	strm _ WriteStream on: ''.
	d _ Delay forMilliseconds: 200.
	[(s _ self next: 2000) isEmpty
		ifTrue: [self atEndOfFile
			ifTrue: [^ strm contents]
			ifFalse: [d wait]]
		ifFalse: [strm nextPutAll: s]] repeat

]
