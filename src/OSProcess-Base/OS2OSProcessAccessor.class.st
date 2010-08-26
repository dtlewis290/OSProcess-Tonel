"
I provide access to an operating system process, such as the process in which the Squeak VM is currently running. I am based on the OS2 process model.
"
Class {
	#name : #OS2OSProcessAccessor,
	#superclass : #OSProcessAccessor,
	#category : #'OSProcess-OS2'
}

{ #category : #'platform identification' }
OS2OSProcessAccessor class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for the
	Squeak VM running on the current platform."

	^ OSProcess isOS2

]

{ #category : #'external process access' }
OS2OSProcessAccessor >> primGetSession [
	"Answer the unique identifier for this session of Smalltalk running in this OS Process."

	^ nil

]
