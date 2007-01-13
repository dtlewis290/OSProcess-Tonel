"
I am a stream on an input or output channel provided by the underlying operating system. I behave like an ordinary file stream, except that I can attach myself to an input or output stream which has already been opened by the underlying operating system.
"
Class {
	#name : #AttachableFileStream,
	#superclass : #StandardFileStream,
	#instVars : [
		'autoClose'
	],
	#classVars : [
		'UseIOHandle'
	],
	#category : #'OSProcess-Base'
}

{ #category : #'file creation' }
AttachableFileStream class >> fileNamed: fileName [

	self shouldNotImplement

]

{ #category : #'initialize-release' }
AttachableFileStream class >> initialize [

	"AttachableFileStream initialize"

	UseIOHandle _ (Smalltalk hasClassNamed: #IOHandle)

]

{ #category : #'file creation' }
AttachableFileStream class >> isAFileNamed: fileName [

	self shouldNotImplement

]

{ #category : #'instance creation' }
AttachableFileStream class >> name: aSymbolOrString attachTo: anIOHandle writable: readWriteFlag [ 
	"Create a new instance attached to anIOHandle, where anIOHandle
	represents an open IO channel. For write streams, this represents two
	Smalltalk streams which write to the same OS file or output stream,
	presumably with interleaved output. The purpose of this method is to
	permit a FileStream to be attached to an existing IOHandle, such as
	the IOHandle for standard input, standard output, and standard error."

	^ (super basicNew
		name: aSymbolOrString
		attachTo: anIOHandle
		writable: readWriteFlag) initialize
]

{ #category : #'file creation' }
AttachableFileStream class >> newFileNamed: fileName [

	self shouldNotImplement

]

{ #category : #'file creation' }
AttachableFileStream class >> oldFileNamed: fileName [

	self shouldNotImplement

]

{ #category : #'file creation' }
AttachableFileStream class >> readOnlyFileNamed: fileName [

	self shouldNotImplement

]

{ #category : #registry }
AttachableFileStream class >> register: anObject [
	"An attachable file stream is generally either a second reference to an
	existing file stream, or a reference to a transient object such as a pipe
	endpoint. There is no need to register it for finalization."

	^ anObject
]

{ #category : #examples }
AttachableFileStream class >> stdIn [

	"self stdIn"

	^ self name: 'stdIn' attachTo: OSProcess thisOSProcess stdIn ioHandle writable: false

]

{ #category : #registry }
AttachableFileStream class >> unregister: anObject [
	"An attachable file stream is generally either a second reference to an
	existing file stream, or a reference to a transient object such as a pipe
	endpoint. There is no need to register it for finalization."

	^ anObject
]

{ #category : #converting }
AttachableFileStream >> asAsyncFileReadStream [
	"Answer a replacement for this object, with asynchronous event handling.
	Do not close the ioHandle when this object is finalized."

	self keepOpen.
	^ AsyncFileReadStream
		name: self name
		attachTo: self ioHandle
		writable: self isReadOnly not

]

{ #category : #converting }
AttachableFileStream >> asAttachableFileStream [

	^ self

]

{ #category : #converting }
AttachableFileStream >> asBufferedAsyncFileReadStream [
	"Answer a replacement for this object, with asynchronous event handling
	and buffered output. Do not close the ioHandle when this object is finalized."

	self keepOpen.
	^ BufferedAsyncFileReadStream
		name: self name
		attachTo: self ioHandle
		writable: self isReadOnly not

]

{ #category : #finalization }
AttachableFileStream >> autoClose [
	"Private. Answer true if the file should be automatically closed when 
	this object is finalized."

	^ autoClose
		ifNil: [autoClose _ true]
]

{ #category : #'open/close' }
AttachableFileStream >> close [
	"Close this file."

	self ioHandle ifNotNilDo:
		[:handle | UseIOHandle
			ifTrue:
				[handle close.
				self ioHandle: nil]
			ifFalse:
				[self primCloseNoError: handle.
				self unregister.
				fileID _ nil]]

]

{ #category : #'initialize-release' }
AttachableFileStream >> disableEventHandling [
	"Subclasses may disable event handling"
]

{ #category : #'open/close' }
AttachableFileStream >> ensureOpen [

	self shouldNotImplement

]

{ #category : #finalization }
AttachableFileStream >> finalize [

	self autoClose
		ifTrue: [[self primCloseNoError: fileID] on: Error do: []]
]

{ #category : #'read, write, position' }
AttachableFileStream >> flush [
	"Flush the external OS stream (the one in the C library)."

	OSProcess accessor flushExternalStream: self ioHandle
]

{ #category : #'private - IOHandle' }
AttachableFileStream >> ioHandle [

	UseIOHandle
		ifTrue: [^ super ioHandle]
		ifFalse: [^ fileID]
]

{ #category : #testing }
AttachableFileStream >> isPipe [

	^ false

]

{ #category : #finalization }
AttachableFileStream >> keepOpen [
	"Do not allow the file to be closed when this object is finalized."

	autoClose _ false

]

{ #category : #attaching }
AttachableFileStream >> name: aSymbolOrString attachTo: anIOHandle writable: readWriteFlag [
	"Attach to an existing file handle, assumed to have been previously opened by the underlying operating system."

	name _ aSymbolOrString.
	UseIOHandle
		ifTrue: [self ioHandle: anIOHandle]
		ifFalse: [fileID _ anIOHandle].
	readWriteFlag ifTrue: [self readWrite] ifFalse: [self readOnly].
	self ascii.
	UseIOHandle ifFalse: [self register]

]

{ #category : #'open/close' }
AttachableFileStream >> open [

	self shouldNotImplement

]

{ #category : #'open/close' }
AttachableFileStream >> open: fileName forWrite: writeMode [

	self shouldNotImplement

]

{ #category : #'open/close' }
AttachableFileStream >> openReadOnly [

	self shouldNotImplement

]

{ #category : #'open/close' }
AttachableFileStream >> reopen [

	self shouldNotImplement

]

{ #category : #'read, write, position' }
AttachableFileStream >> upToEnd [
	"Answer a subcollection from the current access position through the last element
	of the receiver. This is slower than the method in StandardFileStream, but it
	works with pipes which answer false to #atEnd when no further input is
	currently available, but the pipe is not yet closed."

	| newStream buffer nextBytes |
	buffer _ buffer1 species new: 1000.
	newStream _ WriteStream on: (buffer1 species new: 100).
	[self atEnd or: [(nextBytes _ self nextInto: buffer) isEmpty]]
		whileFalse: [newStream nextPutAll: nextBytes].
	^ newStream contents

]

{ #category : #'read, write, position' }
AttachableFileStream >> upToEndOfFile [
	"Answer a subcollection from the current access position through
	the last element of the receiver.  Use #atEndOfFile to determine end
	of file status with feof(), required for reliable end of file test on
	OS pipes."

	| newStream buffer |
	buffer _ buffer1 species new: 1000.
	newStream _ WriteStream on: (buffer1 species new: 100).
	[self atEndOfFile] whileFalse: [newStream nextPutAll: (self nextInto: buffer)].
	^ newStream contents
]
