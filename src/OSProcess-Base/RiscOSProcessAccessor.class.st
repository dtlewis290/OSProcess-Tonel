"
I provide access to the operating system process in which the Squeak VM is currently running. I am based on the RiscOS task model. There is only one instance of me, and instances of RiscOSProcess depend on me to provide access to the operating system process which they represent. I know how to create child processes. I use a semaphore to receive signals when child processes die, and I notify my dependents (instances ofRiscOSProcess) when these events occur.

"
Class {
	#name : #RiscOSProcessAccessor,
	#superclass : #OSProcessAccessor,
	#category : #'OSProcess-RiscOS'
}

{ #category : #'platform identification' }
RiscOSProcessAccessor class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for the
	Squeak VM running on the current platform."

	^ OSProcess isRiscOS

]

{ #category : #'fork and exec' }
RiscOSProcessAccessor >> primForkAndExec: executableFile
	withArgs: anArrayOfArgumentStrings
	argCount: numberOfArgumentStrings
	withEnv: anArrayOfEnvironmentStrings
	envCount: numberOfEnvironmentStrings
	stdIn: inputFileHandle
	stdOut: outputFileHandle
	stdErr: errorFileHandle [
	"Parameters are expected to have been properly prepared by the caller,
	including string values which are to be null terminated strings.
	In other words, all strings should have (Character value: 0) as the
	last element in the string."
]

{ #category : #'external process access' }
RiscOSProcessAccessor >> primGetSession [
	"Answer the unique identifier for this session of Smalltalk running in this OS Process."

	^ nil

]
