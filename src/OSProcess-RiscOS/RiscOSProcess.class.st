"
I represent an Acorn RiscOS operating system task, such as the task in which the Squeak VM is currently running. I collaborate with a singleton instance of RiscOSProcessAccessor to provide primitive access to the external operating system. My instance variables are maintained as a convenience to allow inspection of a RiscOSProcess. Access to these variables should always be done with my accessor methods, which update the instance variables by querying my RiscOSProcessAccessor.

"
Class {
	#name : #RiscOSProcess,
	#superclass : #ThisOSProcess,
	#category : #'OSProcess-RiscOS'
}

{ #category : #'platform identification' }
RiscOSProcess class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for
	the Squeak VM running on the current platform."

	^ self isRiscOS

]

{ #category : #utility }
RiscOSProcess class >> makeVmIn: buildDirectoryPathName [
	"Rebuild the virtual machine and plugins in the buildDirectoryPathName
	directory. If the build is successful, save the image and restart
	using the new VM. This assumes that the currently executing VM is
	either located in, or linked to, the buildDirectoryPathName directory."

]

{ #category : #'child process creation' }
RiscOSProcess >> command: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in
	the standard C library, except that aCommandString runs asynchronously
	in a child process. Answer an instance of ExternalRiscOSProcess which
	is a proxy for the new RiscOS task."

	self notYetImplemented

]

{ #category : #'child process creation' }
RiscOSProcess >> forkAndExec: executableFile arguments: arrayOfStrings environment: stringDictionary descriptors: arrayOf3Streams [
	"Use my processAccessor to call vfork() and execve() and create a
	new child task. Answer a proxy for the new task, an instance of
	ExternalRiscOSProcess."

	self notYetImplemented

]

{ #category : #environment }
RiscOSProcess >> getCwd [
	"Not yet implemented - answer a reasonable default."

	^ OSProcess defaultPathString
]

{ #category : #'initialize - release' }
RiscOSProcess >> initialize [
	"Set my instance variables to reflect the state of the OS process in which 
	this Smalltalk virtual machine is executing."

]

{ #category : #'platform identification' }
RiscOSProcess >> isResponsibleForThisPlatform [
	"Answer true is this is an instance of the class which is responsible for representing
	the OS process for the Squeak VM running on the current platform. A false answer is
	usually the result of running the image on a different platform and VM."

	^ self class isRiscOS

]
