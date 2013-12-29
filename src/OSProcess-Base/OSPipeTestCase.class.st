"
Test operation of OSPipe in blocking and nonBlocking mode.
"
Class {
	#name : #OSPipeTestCase,
	#superclass : #TestCase,
	#category : #'OSProcess-Tests'
}

{ #category : #private }
OSPipeTestCase >> primTestEndOfFileFlag: aSqFileStruct [
	"Answer whether the file represented by aSqFileStruct is at end of file, as determined
	by a call to feof(). This is different from StandardFileStream>>primAtEnd: which answers
	true if the file pointer is at the end of the file, but which does not call feof() to
	determine that an end of file condition has occurred. The difference is significant
	if aSqFileStruct represents a pipe or a device file, which may not be positionable
	in the sense of a conventional disk file."

	<primitive: 'primitiveTestEndOfFileFlag' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #private }
OSPipeTestCase >> readFromAndClose: aPipe writingTo: aStream [

	| s |
	[aPipe atEndOfFile] whileFalse:
		[s := aPipe next: 10000.
		aStream nextPutAll: s asString.
		(Delay forMilliseconds: 100) wait].
	(aPipe respondsTo: #reader) ifTrue: [aPipe reader close].
	^ aStream

]

{ #category : #testing }
OSPipeTestCase >> testBlocking [

	"(OSPipeTestCase selector: #testBlocking) run"

	| p |
	p := OSPipe blockingPipe.
	(1 to: 10) do: [:i | p nextPutAll: 'this is line ', i printString; cr].
	self should: ['this is line 1*' match: (p next: 15)].
	self should: ['this is line 2*' match: (p next: 15)].
	self should: ['this is line 3*' match: (p next: 15)].
	self should: ['this is line 4*' match: (p next: 15)].
	self should: ['this is line 5*' match: (p next: 15)].
	self should: ['this is line 6*' match: (p next: 15)].
	self should: ['this is line 7*' match: (p next: 15)].
	self should: ['this is line 8*' match: (p next: 15)].
	self should: ['this is line 9*' match: (p next: 15)].
	p writer close.
	self shouldnt: p atEnd.
	self should: ['this is line 10*' match: (p next: 16)].
	self should: p atEnd.
	p close

]

{ #category : #testing }
OSPipeTestCase >> testBlockingBufferedPipe [

	"(OSPipeTestCase selector: #testBlockingBufferedPipe) run"

	| p |
	p := ExternalPipe bufferedBlockingPipe.
	[(1 to: 10) do: [:i | p nextPutAll: 'this is line ', i printString; cr].
	(Delay forMilliseconds: 100) wait. "allow pipe reads to complete"
	self should: ['this is line 1*' match: (p next: 15)].
	self should: ['this is line 2*' match: (p next: 15)].
	self should: ['this is line 3*' match: (p next: 15)].
	self should: ['this is line 4*' match: (p next: 15)].
	self should: ['this is line 5*' match: (p next: 15)].
	self should: ['this is line 6*' match: (p next: 15)].
	self should: ['this is line 7*' match: (p next: 15)].
	self should: ['this is line 8*' match: (p next: 15)].
	self should: ['this is line 9*' match: (p next: 15)].
	p writer close.
	self shouldnt: p atEnd.
	self should: ['this is line 10*' match: (p next: 16)].
	self should: p atEnd]
		ensure: [p close]

]

{ #category : #testing }
OSPipeTestCase >> testBlockingPeek [

	"(OSPipeTestCase selector: #testBlockingPeek) run"

	| p |
	p := OSPipe blockingPipe.
	p nextPutAll: 'abc'.
	self assert: (p peek == $a).
	self assert: (p next == $a).
	self assert: (p peek == $b).
	self assert: (p next == $b).
	self assert: (p peek == $c).
	self deny: p atEnd.
	self assert: (p next == $c).
	self deny: p atEnd.
	p closeWriter.
	self assert: p atEnd.
	p close

]

{ #category : #testing }
OSPipeTestCase >> testBlockingPeekBufferedPipe [

	"(OSPipeTestCase selector: #testBlockingPeekBufferedPipe) run"

	| p |
	p := ExternalPipe bufferedBlockingPipe.
	[p nextPutAll: 'abc'.
	(Delay forMilliseconds: 100) wait. "allow pipe reads to complete"
	self assert: (p peek == $a).
	self assert: (p next == $a).
	self assert: (p peek == $b).
	self assert: (p next == $b).
	self assert: (p peek == $c).
	self deny: p atEnd.
	self assert: (p next == $c).
	self deny: p atEnd.
	p closeWriter.
	self assert: p atEnd]
		ensure: [p close]

]

{ #category : #testing }
OSPipeTestCase >> testBufferedUpToEnd [

	"(OSPipeTestCase selector: #testBufferedUpToEnd) debug"

	| s p r1 r2 |
	s := 'some data to put through the pipe'.
	p := OSPipe new.
	self primTestEndOfFileFlag: p reader fileID. "check that OSPP is updated"
	self assert: p setBufferedReader.
	[p nextPutAll: s.
	p closeWriter.
	r1 := p upToEnd. "#atEnd does not detect EOF on a pipe"
	self assert: r1 isEmpty.
	r2 := p upToEndOfFile. "detects EOF correctly, gets remaining data"
	self assert: r2 = s]
		ensure: [p close]

]

{ #category : #testing }
OSPipeTestCase >> testIsAtEndOfFile [

	"(OSPipeTestCase selector: #testIsAtEndOfFile) debug"

	| p |
	p := OSPipe new.
	self primTestEndOfFileFlag: p reader fileID. "check that OSPP is updated"
	self deny: (OSProcess accessor isAtEndOfFile: p reader fileID).
	self deny: p reader atEnd.
	self deny: p atEnd.
	self assert: (p reader basicNext == nil).
	self deny: (OSProcess accessor isAtEndOfFile: p reader fileID).
	self deny: p reader atEnd.
	self deny: p atEnd.
	p writer nextPut: $X.
	self assert: (p reader basicNext == $X).
	self deny: (OSProcess accessor isAtEndOfFile: p reader fileID).
	self deny: p reader atEnd.
	self deny: p atEnd.
	self assert: (p reader basicNext == nil).
	self deny: (OSProcess accessor isAtEndOfFile: p reader fileID).
	self deny: p reader atEnd.
	self deny: p atEnd.

	p writer close.
	self deny: (OSProcess accessor isAtEndOfFile: p reader fileID).
	self deny: p atEndOfFile. "no read yet, so flag has not been set"
	self deny: p reader atEnd.
	self assert: p atEnd. "writer closed and read gives nil"

	self assert: (p reader basicNext == nil). "read operation should set flag"
	self assert: (OSProcess accessor isAtEndOfFile: p reader fileID).
	self deny: p reader atEnd. "#atEnd does not detect EOF on a pipe"
	self assert: p reader atEndOfFile.
	self assert: p atEnd.
	p close

]

{ #category : #testing }
OSPipeTestCase >> testIsAtEndOfFile2 [

	"(OSPipeTestCase selector: #testIsAtEndOfFile2) debug"

	| p s |
	p := OSPipe new.
	[p nextPutAll: 'hello'.
	s := p next: 100.
	self assert: s = 'hello'.
	self deny: p atEndOfFile.
	p closeWriter.
	self deny: p atEndOfFile.
	s := p next: 100.
	self assert: s = ''.
	self assert: p atEndOfFile]
		ensure: [p close]

]

{ #category : #testing }
OSPipeTestCase >> testNonBlocking [

	"(OSPipeTestCase selector: #testNonBlocking) run"

	| p ws str |
	p := OSPipe nonBlockingPipe.
	self writeStuffOnThenClose: p.
	ws := self readFromAndClose: p writingTo: (WriteStream on: String new).
	str := (ws contents last: 16).
	self should: ['this is line 10*' match: str].
	p close

]

{ #category : #testing }
OSPipeTestCase >> testNonBlockingBufferedPipe [

	"(OSPipeTestCase selector: #testNonBlockingBufferedPipe) run"

	| p ws str |
	p := ExternalPipe bufferedNonBlockingPipe.
	[self writeStuffOnThenClose: p.
	self assert: (p peek == nil).
	(Delay forMilliseconds: 100) wait. "allow pipe reads to complete"
	ws := self readFromAndClose: p writingTo: (WriteStream on: String new).
	str := (ws contents last: 16).
	self should: ['this is line 10*' match: str]]
		ensure: [p close]

]

{ #category : #testing }
OSPipeTestCase >> testNonBlockingPeek [

	"(OSPipeTestCase selector: #testNonBlockingPeek) run"

	| p |
	p := OSPipe nonBlockingPipe.
	p nextPutAll: 'abc'.
	self assert: (p peek == $a).
	self assert: (p next == $a).
	self assert: (p peek == $b).
	self assert: (p next == $b).
	self assert: (p peek == $c).
	self deny: p atEnd.
	self assert: (p next == $c).
	self deny: p atEnd.
	p closeWriter.
	self assert: p atEnd.
	p close

]

{ #category : #testing }
OSPipeTestCase >> testNonBlockingPeekBufferedPipe [

	"(OSPipeTestCase selector: #testNonBlockingPeekBufferedPipe) run"

	| p |
	p := ExternalPipe bufferedNonBlockingPipe.
	[p nextPutAll: 'abc'.
	self assert: (p peek == nil).
	(Delay forMilliseconds: 100) wait. "allow pipe reads to complete"
	self assert: (p peek == $a).
	self assert: (p next == $a).
	self assert: (p peek == $b).
	self assert: (p next == $b).
	self assert: (p peek == $c).
	self deny: p atEnd.
	self assert: (p next == $c).
	self deny: p atEnd.
	p closeWriter.
	self assert: p atEnd]
		ensure: [p close]

]

{ #category : #private }
OSPipeTestCase >> writeStuffOnThenClose: aPipe [

	^ [(1 to: 10) do:
		[:i |
		[aPipe nextPutAll: 'this is line ', i printString; cr]
			on: Error
			do: ["Ignore error. Test case will still fail, and throwing an error in this
				process would cause a debugger to be scheduled inconveniently."].
		(Delay forMilliseconds: 50) wait].
	(aPipe respondsTo: #writer)
		ifTrue: [[aPipe writer close]
					on: Error
					do: ["Ignore error to avoid a debugger"]]
		ifFalse: [[aPipe close]
					on: Error
					do: ["Ignore error to avoid a debugger"]]]
		forkAt: Processor userBackgroundPriority
]
