"
I represent a thread of execution within a Windows process. May threadID is a unique
identifier for the thread, and my handle is a Windows HANDLE to the thread. My handle
should be closed when the thread exits.
"
Class {
	#name : #WindowsThread,
	#superclass : #Object,
	#instVars : [
		'threadID',
		'handle',
		'runState'
	],
	#category : 'OSProcess-Win32'
}

{ #category : #'instance creation' }
WindowsThread class >> threadID: anInteger handle: aHandleObject [

	^ super new threadID: anInteger; handle: aHandleObject; initialize

]

{ #category : #'instance creation' }
WindowsThread class >> threadID: anInteger handle: aHandleObject running: trueOrFalse [

	| thread |
	thread := super new threadID: anInteger; handle: aHandleObject; initialize.
	trueOrFalse ifTrue: [thread running].
	^ thread

]

{ #category : #'initialize - release' }
WindowsThread >> closeHandle [
	"Clean up after thread exits."

	OSProcess accessor primCloseHandle: handle.
	handle := nil

]

{ #category : #'setting run state' }
WindowsThread >> complete [
	"Thread has exited."

	self closeHandle; runState: #complete

]

{ #category : #accessing }
WindowsThread >> handle [
	"A Windows HANDLE represented as a ByteArray."

	^ handle
]

{ #category : #accessing }
WindowsThread >> handle: aHandleObject [
	"A Windows HANDLE represented as a ByteArray."

	handle := aHandleObject
]

{ #category : #'initialize - release' }
WindowsThread >> initialize [

	self runState
]

{ #category : #testing }
WindowsThread >> isComplete [

	^ self runState == #complete
]

{ #category : #testing }
WindowsThread >> isRunning [

	^ self runState == #running
]

{ #category : #printing }
WindowsThread >> printOn: aStream [

	super printOn: aStream.
	aStream nextPutAll: ' (', self threadID printString, ', ', self runState, ')'

]

{ #category : #accessing }
WindowsThread >> runState [

	^ runState ifNil: [self unknownRunState]

]

{ #category : #accessing }
WindowsThread >> runState: aSymbol [

	runState := aSymbol

]

{ #category : #'setting run state' }
WindowsThread >> running [
	"Thread is scheduled to run."

	self runState: #running

]

{ #category : #'initialize - release' }
WindowsThread >> terminate [
	"Force an exit. No cleanup is performed. Use with caution for a thread which
	is (for example) manipulating a mutex."

	(self isRunning and: [self handle notNil]) ifTrue:
		[OSProcess accessor primTerminateThread: self handle.
		self complete]

]

{ #category : #accessing }
WindowsThread >> threadID [
	"A unique identifier for the thread."

	^ threadID

]

{ #category : #accessing }
WindowsThread >> threadID: anInteger [
	"A unique identifier for the thread."

	threadID := anInteger

]

{ #category : #'setting run state' }
WindowsThread >> unknownRunState [
	"Unable to determine the current run state of the thread, possibly because
	this is a stale reference to a thread which no longer exists."

	self runState: #unknownRunState

]
