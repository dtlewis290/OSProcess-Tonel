"
BufferedAsyncFileReadStream adds output buffering behavior to an event driven file stream, permitting blocking reads without risk of blocking the Squeak VM. This is useful for OS pipes, for which Squeak may wish to read and write the pipe without concern for VM deadlocks.

A BufferedAsyncFileReadStream may be set for either blocking or nonblocking reads. When in blocking mode, a Smalltalk Process that requests a read will be blocked until data is available, but the VM will not be blocked and other Smalltalk Processes can proceed normally.

Whenever data becomes available, a dataAvailableSemaphore is signalled and a #changed event is generated.
"
Class {
	#name : #BufferedAsyncFileReadStream,
	#superclass : #AsyncFileReadStream,
	#instVars : [
		'nonBlockingMode',
		'readBuffer',
		'readSyncSemaphore',
		'dataAvailableSemaphore'
	],
	#category : 'OSProcess-Base'
}

{ #category : #examples }
BufferedAsyncFileReadStream class >> stdIn [

	"self stdIn"

	^ super stdIn

]

{ #category : #finalization }
BufferedAsyncFileReadStream >> actAsExecutor [

	super actAsExecutor.
	nonBlockingMode := nil.
	readBuffer := nil.
	readSyncSemaphore := nil.
	dataAvailableSemaphore := nil

]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> appendAllToBuffer: chars [
	"Append all chars to readBuffer, then signal dataAvailableSemaphore to inform
	any blocked reader that the read can proceed. Also generate a #changed event
	to inform any interested objects that new data has become available."

	| pos |
	self readSyncSemaphore critical:
		[(self readBuffer position > self maxReadBufferSize) ifTrue:
			["Read buffer is getting too large. Replace it."
			self readBuffer: (ReadWriteStream on: readBuffer upToEnd)].
		pos := readBuffer position.
		readBuffer setToEnd.
		readBuffer nextPutAll: chars.
		readBuffer position: pos].
	self dataAvailableSemaphore signal.
	self changed
]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> appendToBuffer: aCharacter [
	"Append aCharacter to readBuffer, then signal dataAvailableSemaphore to inform
	any blocked reader that the read can proceed, and trigger a #dataReady event to
	inform any interested objects that new data has become available."

	| pos |
	self readSyncSemaphore critical:
		[pos := self readBuffer position.
		readBuffer setToEnd.
		readBuffer nextPut: aCharacter.
		readBuffer position: pos].
	self dataAvailableSemaphore signal.
	self changed
]

{ #category : #converting }
BufferedAsyncFileReadStream >> asAsyncFileReadStream [
	"Answer a replacement for this object, with asynchronous event handling but
	no buffering."

	^ AsyncFileReadStream
		name: self name
		attachTo: self ioHandle
		writable: self isReadOnly not

]

{ #category : #converting }
BufferedAsyncFileReadStream >> asBufferedAsyncFileReadStream [

	^ self
]

{ #category : #testing }
BufferedAsyncFileReadStream >> atEnd [
	"Answer whether the receiver can access any more objects.

	Warning: If this instance represents the reader end of an OS pipe, it
	is possible for the #atEnd test to give a false negative. In particular, after
	closing the writer end of an empty OSPipe, the reader may not appear to
	be atEnd until some time has elapsed, or until an explicit read on the pipe
	causes the status to be updated. To illustrate the problem:

		(OSPipe new setBufferedReader; yourself) closeWriter; atEnd>>false
		(OSPipe new ) closeWriter; next; yourself; atEnd>>true
		(OSPipe new setBufferedReader; yourself) closeWriter; next; yourself; atEnd>>true"

	^ self readSyncSemaphore
		critical: [self readBuffer atEnd
				and: [super atEnd]]
]

{ #category : #testing }
BufferedAsyncFileReadStream >> atEndOfFile [
	"Answer whether the receiver is at its end based on the result of
	the last read operation. This uses feof() to test the underlying file
	stream status, and can be used as an alternative to #atEnd, which
	does not properly report end of file status for an OSPipe."

	^ self readSyncSemaphore
		critical: [self readBuffer atEnd
				and: [fileID isNil
						or: [OSProcess accessor isAtEndOfFile: fileID]]]
]

{ #category : #'read, write, position' }
BufferedAsyncFileReadStream >> basicNext [
	"Answer the next byte from this file, or nil if at the end of the file.
	If the readBuffer is empty, force a basicNext in order to ensure that
	the end of file flag is updated (in stdio stream)."

	(self readSyncSemaphore
			critical: [self readBuffer atEnd])
		ifTrue: [^ super basicNext]
		ifFalse: [[self isBlocking]
				ifTrue: [self waitForDataReady].
			^ self readSyncSemaphore
				critical: [readBuffer next]]
]

{ #category : #accessing }
BufferedAsyncFileReadStream >> dataAvailableSemaphore [
	"Signalled one or more times when data becomes available. Only one Process
	is permitted to wait on this Semaphore."

	^ dataAvailableSemaphore ifNil: [dataAvailableSemaphore := Semaphore new]

]

{ #category : #testing }
BufferedAsyncFileReadStream >> isBlocking [
	"Answer true if set to blocking mode."

	^ self nonBlockingMode not
]

{ #category : #defaults }
BufferedAsyncFileReadStream >> maxReadBufferSize [
	"Replace readBuffer when position exceeds this."

	^ 40000

]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> moveAvailableDataFrom: sqFile [

	| count bufferSize buffer |
	(readBuffer notNil and: [readBuffer size > self readBufferMemoryWarningThreshold])
		ifTrue: [self notify: 'buffer size ', readBuffer size asString.
			^(Delay forSeconds: 2) wait].
	bufferSize := self readAheadChunkSize.
	buffer := String new: bufferSize.
	count := self readAvailableDataFrom: sqFile into: buffer.
	count > 0
		ifTrue:
			[count == bufferSize
				ifTrue:
					[self appendAllToBuffer: buffer]
				ifFalse:
					[self appendAllToBuffer: (buffer copyFrom: 1 to: count)]]
		ifFalse:
			[(self closed or: [OSProcess accessor isAtEndOfFile: self ioHandle])
				ifTrue:
					[self disableEventHandling]]

]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> moveAvailableDataToBuffer [

	^ self moveAvailableDataFrom: (OSProcess accessor handleFromAccessor: self ioHandle).

]

{ #category : #'read, write, position' }
BufferedAsyncFileReadStream >> next [

	((self readSyncSemaphore
				critical: [self readBuffer atEnd])
			and: [self isBlocking])
		ifTrue: [self waitForDataReady].
	^ self readSyncSemaphore
		critical: [readBuffer next]
]

{ #category : #'read, write, position' }
BufferedAsyncFileReadStream >> next: n into: aString startingAt: startIndex [
	"Read n bytes into the given string.
	Return aString or a partial copy if less than n elements have been read."

	| count |
	count := self readInto: aString startingAt: startIndex count: n.
	count = n
		ifTrue: [^ aString]
		ifFalse: [^ aString copyFrom: 1 to: startIndex+count-1]
]

{ #category : #accessing }
BufferedAsyncFileReadStream >> nonBlockingMode [
	"True if nonblocking read behavior should be implemented"

	^ nonBlockingMode ifNil: [nonBlockingMode := true]

]

{ #category : #accessing }
BufferedAsyncFileReadStream >> nonBlockingMode: trueOrFalse [
	"True if nonblocking read behavior should be implemented"

	nonBlockingMode := trueOrFalse

]

{ #category : #'read, write, position' }
BufferedAsyncFileReadStream >> peek [
	"Answer what would be returned if the message next were sent to the
	receiver. If the receiver is at the end, answer nil. "

	((self readSyncSemaphore
				critical: [self readBuffer atEnd])
			and: [self isBlocking])
		ifTrue: [self waitForDataReady].
	^ self readSyncSemaphore
		critical: [readBuffer peek]
]

{ #category : #defaults }
BufferedAsyncFileReadStream >> readAheadChunkSize [
	"The async read ahead process will read at most this many characters.
	Notes: On my system (dtl), a chunk size of 2000 leads to ExternalCommandShell
	overdriving the stdout stream when doing (for example) a long directory listing.
	I have added error handling to accommodate this, but I do know know how
	reliable it is, so I would prefer to avoid generating the condition. A chunk
	size of 200 is small enough that performance is noticably impacted in a
	CommandShell window. A chunk size of 1000 seems to produce good overall
	behavior."

	^ 1000
]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> readAvailableDataFrom: sqFile into: buffer [
	"Some implementations of the read primitive may read character by character
	from standard input. Handle that case by looping while data available. Answer
	the number of bytes read into the buffer."

	| bytesRead |
	bytesRead := 0.
	[ | count |
		[count := self primRead: sqFile
				into: buffer
				startingAt: 1 + bytesRead
				count: self readAheadChunkSize - bytesRead]
			on: Error	"Could fail if closed"
			do: [count := 0].
	bytesRead := bytesRead + count.
	count > 0] whileTrue.
	^ bytesRead.

]

{ #category : #accessing }
BufferedAsyncFileReadStream >> readBuffer [
	"Read ahead buffer, filled asynchronously as data becomes available on the IO channel"

	^ readBuffer ifNil: [readBuffer := ReadWriteStream on: String new]

]

{ #category : #accessing }
BufferedAsyncFileReadStream >> readBuffer: aStream [

	readBuffer := aStream
]

{ #category : #defaults }
BufferedAsyncFileReadStream >> readBufferMemoryWarningThreshold [
	"A read buffer larger that this may start causing problems. Issue a warning
	before the object memory becomes too large." 

	^self maxReadBufferSize * 1000

]

{ #category : #'read, write, position' }
BufferedAsyncFileReadStream >> readInto: byteArray startingAt: startIndex count: count [ 
	"Read into the given array as specified, and return the count actually
	transferred. "

	| s size |
	self isBlocking
		ifTrue: [self waitForDataReady: count.
			s := self readSyncSemaphore
						critical: [self readBuffer next: count].
			size := count]
		ifFalse: [size := self readBuffer size - readBuffer position min: count.
			s := self readSyncSemaphore
						critical: [self readBuffer next: size]].
	byteArray
		replaceFrom: startIndex
		to: startIndex + size - 1
		with: s.
	^ size
]

{ #category : #accessing }
BufferedAsyncFileReadStream >> readSyncSemaphore [
	"A semaphore for synchronizing access to readBuffer"

	^ readSyncSemaphore ifNil: [readSyncSemaphore := Semaphore forMutualExclusion]
]

{ #category : #'initialize-release' }
BufferedAsyncFileReadStream >> setBlocking [
	"Set for blocking reads. Default is nonblocking mode."

	self nonBlockingMode: false

]

{ #category : #'initialize-release' }
BufferedAsyncFileReadStream >> setNonBlocking [
	"Set for nonblocking reads. This is the default mode."

	self nonBlockingMode: true

]

{ #category : #'read, write, position' }
BufferedAsyncFileReadStream >> upTo: delim [ 

	^ self readSyncSemaphore critical: [self readBuffer upTo: delim]

]

{ #category : #'read, write, position' }
BufferedAsyncFileReadStream >> upToEndOfFile [
	"Answer a subcollection from the current access position through
	the last element of the receiver.  Use #atEndOfFile to determine end
	of file status with feof(), required for reliable end of file test on
	OS pipes. Close the file when end of file is detected."

	| newStream buffer |
	buffer := buffer1 species new: 1000.
	newStream := WriteStream on: (buffer1 species new: 100).
	[self atEndOfFile] whileFalse:
		[self moveAvailableDataToBuffer.
		newStream nextPutAll: (self nextInto: buffer)].
	self isReadOnly ifTrue: [self close].
	^ newStream contents

]

{ #category : #updating }
BufferedAsyncFileReadStream >> update: aParameter [
	"A #changed event is generated as a side effect of this method"

	(aParameter == self eventHandler)
		ifTrue: [self moveAvailableDataToBuffer]

]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> waitForBufferAvailable [
	"Block if the readBuffer has grown too large. No-op for now, but add
	this later if large pipes prove to be a problem."
]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> waitForDataReady [
	"Block until at least one character is available in the readBuffer. This is not
	thread safe, and only one Process is permitted to send this message."

	self dataAvailableSemaphore wait

]

{ #category : #'read ahead buffer' }
BufferedAsyncFileReadStream >> waitForDataReady: count [ 
	"Block until at least count characters are available in the readBuffer"

	[self readSyncSemaphore
		critical: [self readBuffer size - readBuffer position < count]]
		whileTrue: [self waitForDataReady]
]
