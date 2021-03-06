"
I represent an external RiscOS task other than the process in which this Squeak is executing. I maintain information about the state of the external task during and after the lifetime of the task. In particular, I hold the exit status of the task after it completes execution. When the external task changes state (e.g. it exits), the VM signals a Squeak semaphore. A singleton RiscOSProcessAccessor maintains a process which waits on the semaphore, and sends a changed: #childProcessStatus message to itself, thereby notifying its dependent RiscOSProcess (a singleton) to check the status of all its ExternalRiscOSProcess children, and #update: them accordingly.

"
Class {
	#name : #ExternalRiscOSProcess,
	#superclass : #ExternalOSProcess,
	#instVars : [
		'ppid',
		'exitStatus'
	],
	#category : #'OSProcess-RiscOS'
}

{ #category : #'platform identification' }
ExternalRiscOSProcess class >> isResponsibleForThisPlatform [
	"Answer true if, for the current platform, this class is responsible for representing
	an OS process other than that in which the Squeak VM is currently running."

	^ self isRiscOS

]
