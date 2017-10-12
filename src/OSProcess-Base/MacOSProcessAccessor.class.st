"
I provide access to an operating system process, such as the process in which the Squeak VM is currently running. I am based on the Macintosh process model.
"
Class {
	#name : #MacOSProcessAccessor,
	#superclass : #OSProcessAccessor,
	#category : 'OSProcess-Mac'
}

{ #category : #'platform identification' }
MacOSProcessAccessor class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for the
	Squeak VM running on the current platform."

	^ OSProcess isNonUnixMac

]

{ #category : #'external process access' }
MacOSProcessAccessor >> primGetSession [
	"Answer the unique identifier for this session of Smalltalk running in this OS Process."

	^ nil

]
