"
I am a stream on an input or output channel provided by the underlying operating system. I behave like an ordinary file stream, except that I can attach myself to an input or output stream which has already been opened by the underlying operating system.
"
Class {
	#name : #AttachableFileStream,
	#superclass : #StandardFileStream,
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
	"Create a new instance attached to anIOHandle, where anIOHandle represents
	an open IO channel. For write streams, this represents two Smalltalk streams
	which write to the same OS file or output stream, presumably with interleaved
	output. The purpose of this method is to permit a FileStream to be attached to
	an existing IOHandle, such as the IOHandle for standard input, standard output,
	and standard error."

	^ super new name: aSymbolOrString attachTo: anIOHandle writable: readWriteFlag
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

{ #category : #'open/close' }
AttachableFileStream >> close [
	"Close this file."

	self ioHandle ifNotNilDo:
		[:handle | UseIOHandle
			ifTrue:
				[handle close.
				self ioHandle: nil]
			ifFalse:
				[self primClose: handle.
				self unregister.
				fileID _ nil]]

]

{ #category : #'open/close' }
AttachableFileStream >> ensureOpen [

	self shouldNotImplement

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

{ #category : #'private - IOHandle' }
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
	works with pipes which always answer true to #atEnd."

	| newStream c |
	newStream _ WriteStream on: (buffer1 species new: 100).
	[self atEnd not and: [(c _ self next) notNil]] whileTrue: [newStream nextPut: c].
	^ newStream contents
]
