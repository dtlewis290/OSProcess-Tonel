"
I represent an external MacOS process other than the process in which this Squeak is executing. I maintain information about the state of the external process during and after the lifetime of the process. In particular, I hold the exit status of the process after it completes execution. When the external process changes state (e.g. it exits), the VM signals a Squeak semaphore. A singleton MacOSProcessAccessor maintains a process which waits on the semaphore, and sends a changed: #childProcessStatus message to itself, thereby notifying its dependent MacOSProcess (a singleton) to check the status of all its ExternalMacOSProcess children, and #update: them accordingly.
"
Class {
	#name : #ExternalMacOSProcess,
	#superclass : #ExternalOSProcess,
	#instVars : [
		'ppid',
		'exitStatus'
	],
	#category : #'OSProcess-Mac'
}

{ #category : #'platform identification' }
ExternalMacOSProcess class >> isResponsibleForThisPlatform [
	"Answer true if, for the current platform, this class is responsible for representing
	an OS process other than that in which the Squeak VM is currently running."

	^ self isNonUnixMac

]
