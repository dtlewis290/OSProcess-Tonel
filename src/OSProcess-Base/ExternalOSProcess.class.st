"
I represent an OSProcess other than the process in which this Squeak is executing. I maintain information about the state of the external process during and after the lifetime of the process.
"
Class {
	#name : #ExternalOSProcess,
	#superclass : #OSProcess,
	#instVars : [
		'runState',
		'initialStdIn',
		'initialStdOut',
		'initialStdErr'
	],
	#category : 'OSProcess-Base'
}

{ #category : #'concrete subclasses' }
ExternalOSProcess class >> concreteClass [

	"ExternalOSProcess concreteClass"

	^ self subclasses
		detect: [:c | c isResponsibleForThisPlatform]
		ifNone: [self notify: self printString,
					': No concrete class implementation available for system type ',
					self platformName printString.
				nil]


]

{ #category : #'instance creation' }
ExternalOSProcess class >> exec: programName [
	"Run a program in an external OS process, and answer an instance of myself
	which represents the external process."

	"ExternalOSProcess exec: '/bin/ls'"

	^ self concreteClass exec: programName

]

{ #category : #shell }
ExternalOSProcess class >> shellFlags [

	^ '-c'.
]

{ #category : #accessing }
ExternalOSProcess >> accessor [
	"Answer an OSProcessAccessor which may be used to obtain information about
	the external OS process which I represent."

	^ OSProcess thisOSProcess processAccessor

]

{ #category : #'initialize - release' }
ExternalOSProcess >> closeInitialStdErr [

	initialStdErr ifNotNil: [initialStdErr close]

]

{ #category : #'initialize - release' }
ExternalOSProcess >> closeInitialStdIn [

	initialStdIn ifNotNil: [initialStdIn close]

]

{ #category : #'initialize - release' }
ExternalOSProcess >> closeInitialStdOut [

	initialStdOut ifNotNil: [initialStdOut close]

]

{ #category : #'initialize - release' }
ExternalOSProcess >> closeStreams [

	self closeInitialStdIn; closeInitialStdOut; closeInitialStdErr
]

{ #category : #'setting run state' }
ExternalOSProcess >> complete [
	"Process has exited and has been reaped. It no longer exists in the external operating system."

	self runState: #complete

]

{ #category : #accessing }
ExternalOSProcess >> initialStdErr [
	"The stderr stream at the time the child process is invoked. If the same as
	stderr for the current Squeak process, it may change as a result of Squeak
	using its stderr stream. The child process may also modify its actual stderr;
	therefore this is not an accurate representation of the child process stderr
	during the life of the child process."

	^ initialStdErr
]

{ #category : #accessing }
ExternalOSProcess >> initialStdErr: anExternalStream [

	initialStdErr := anExternalStream
]

{ #category : #accessing }
ExternalOSProcess >> initialStdIn [
	"The stdin stream at the time the child process is invoked. If the same as
	stdin for the current Squeak process, it may change as a result of Squeak
	using its stdin stream. The child process may also modify its actual stdin;
	therefore this is not an accurate representation of the child process stdin
	during the life of the child process."

	^ initialStdIn
]

{ #category : #accessing }
ExternalOSProcess >> initialStdIn: anExternalStream [

	initialStdIn := anExternalStream
]

{ #category : #accessing }
ExternalOSProcess >> initialStdOut [
	"The stdout stream at the time the child process is invoked. If the same as
	stdout for the current Squeak process, it may change as a result of Squeak
	using its stdout stream. The child process may also modify its actual stdout;
	therefore this is not an accurate representation of the child process stdout
	during the life of the child process."

	^ initialStdOut
]

{ #category : #accessing }
ExternalOSProcess >> initialStdOut: anExternalStream [

	initialStdOut := anExternalStream
]

{ #category : #'initialize - release' }
ExternalOSProcess >> initialize [

	self notYetRunning
]

{ #category : #testing }
ExternalOSProcess >> isAccessible [

	^ self accessor canAccessChildProcess: self
]

{ #category : #testing }
ExternalOSProcess >> isComplete [

	^ self runState == #complete
]

{ #category : #testing }
ExternalOSProcess >> isNotYetRunning [

	^ self runState == #notYetRunning
]

{ #category : #testing }
ExternalOSProcess >> isRunning [

	^ self runState == #running
]

{ #category : #'setting run state' }
ExternalOSProcess >> notYetRunning [
	"Process has not yet entered running state."

	self runState: #notYetRunning

]

{ #category : #printing }
ExternalOSProcess >> printOn: aStream [

	super printOn: aStream.
	self isComplete ifTrue: [ aStream nextPutAll: ' (', self runState, ' with status ', self exitStatus printString, ')' ]
		ifFalse: [ aStream nextPutAll: ' (', self runState asString, ')' ]
]

{ #category : #accessing }
ExternalOSProcess >> runState [

	^ runState ifNil: [self unknownRunState]

]

{ #category : #accessing }
ExternalOSProcess >> runState: aSymbol [

	runState := aSymbol.
	self changed: #runState

]

{ #category : #'setting run state' }
ExternalOSProcess >> running [
	"Process is actively running."

	self runState: #running

]

{ #category : #testing }
ExternalOSProcess >> succeeded [
	"Answer true if my process completed successfully. Be optimistic here, and let
	my subclasses implement the details."

	^ self isComplete
]

{ #category : #'setting run state' }
ExternalOSProcess >> unknownRunState [
	"Unable to determine the current run state of the process, possibly because
	this is a stale reference to a process which no longer exists."

	self runState: #unknownRunState

]

{ #category : #updating }
ExternalOSProcess >> update: aParameter [
	"Notify any dependents if my run state changes. My subclasses will do additional
	updating when the run state changes."

	aParameter == #runState ifTrue: [self changed: #runState]

]
