"
I represent a Macintosh operating system process, such as the process in which the Squeak VM is currently running. I collaborate with an instance of MacOSProcessAccessor to provide primitive access to the external operating system. My instance variables are maintained as a convenience to allow inspection of an OSProcess. Access to these variables should always be done with my accessor methods, which update the instance variables by querying my MacOSProcessAccessor.
"
Class {
	#name : #MacProcess,
	#superclass : #ThisOSProcess,
	#category : #'OSProcess-Mac'
}

{ #category : #'platform identification' }
MacProcess class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for
	the Squeak VM running on the current platform."

	^ self isNonUnixMac

]

{ #category : #'child process creation' }
MacProcess >> command: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in
	the standard C library, except that aCommandString runs asynchronously
	in a child process. Answer an instance of ExternalMacOSProcess which
	is a proxy for the new MacOS process."

	self notYetImplemented

]

{ #category : #'child process creation' }
MacProcess >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [
	"Use my processAccessor to call vfork() and execve() and create a
	new child task. Answer a proxy for the new task, an instance of
	ExternalMacOSProcess."

	self notYetImplemented

]

{ #category : #environment }
MacProcess >> getCwd [
	"Not yet implemented - answer a reasonable default."

	^ FileDirectory default pathName
]

{ #category : #'initialize - release' }
MacProcess >> initialize [
	"Set my instance variables to reflect the state of the OS process in which 
	this Smalltalk virtual machine is executing."

]

{ #category : #'platform identification' }
MacProcess >> isResponsibleForThisPlatform [
	"Answer true is this is an instance of the class which is responsible for representing
	the OS process for the Squeak VM running on the current platform. A false answer is
	usually the result of running the image on a different platform and VM."

	^ self class isNonUnixMac
]
