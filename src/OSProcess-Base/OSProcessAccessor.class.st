"
I am an abstract class whose subclasses provide access to an operating system process, such as the process in which the Squeak VM is currently running. My subclasses collaborate with instances of OSProcess subclasses.

The single instance ThisOSProcessAccessor provides access to the OS process in which the virtual machine is running. On Unix, this instance sets a signal handler to respond to externally generated sigchld signals. This must be done after each image restart in order to call a primitive which informs the VM of the  identity of the semaphore to signal. A similar mechanism is used for Windows to obtain exit status of external OS processes. ThisOSProcessor maintains a process that waits on child exit events and updates a dependent OSProcess of changes to external OS processes.

When an image is restarted on a different kind of platform, a new instance is assigned to ThisOSProcessAccessor to provide access to the virtual machine OS process.

"
Class {
	#name : #OSProcessAccessor,
	#superclass : #Model,
	#instVars : [
		'sessionIdentifier',
		'grimReaper',
		'canObtainSessionIdentifierFromPlugin'
	],
	#classVars : [
		'EmulateWin32FileLocking',
		'FileLockRegistry',
		'ThisOSProcessAccessor',
		'UseIOHandle'
	],
	#category : 'OSProcess-Base'
}

{ #category : #'concrete subclasses' }
OSProcessAccessor class >> concreteClass [

	"OSProcessAccessor concreteClass"

	^ self subclasses
		detect: [:c | c isResponsibleForThisPlatform]
		ifNone: [self notify: self printString,
					': No concrete class implementation available for system type ',
					OSProcess platformName printString.
				nil]


]

{ #category : #'initialize-release' }
OSProcessAccessor class >> emulateWin32FileLocking: trueOrFalse [
	"This is a preference that controls whether file locking will attempt to emulation
	Win32 behavior, in which a lock request will fail if the requested region overlaps
	a region for which there is an existing lock. This behavior is valid only for locks
	managed within a single Squeak image, and will not produce the expected results
	for a Squeak image cooperating with another Squeak image, or with some other
	external program.

	Use of the Win32 emulation may result in performance penalties for an application
	that performs a large number of lock requests, such as a database."

	"self emulateWin32FileLocking: true"
	"self emulateWin32FileLocking: false"

	EmulateWin32FileLocking := trueOrFalse

]

{ #category : #'instance creation' }
OSProcessAccessor class >> forThisOSProcess [
	"Answer a single instance corresponding to the OS process in which this 
	Smalltalk image is executing."

	"OSProcessAccessor forThisOSProcess"

	ThisOSProcessAccessor
		ifNotNil: [ThisOSProcessAccessor isResponsibleForThisPlatform
					ifTrue:
						["Common case, platform has not changed"
						^ThisOSProcessAccessor ]
					ifFalse:
						["We are running on a different platform, so start a new accessor"
						ThisOSProcessAccessor changed: #invalidProcessAccessor.
						ThisOSProcessAccessor finalize]].
	^ ThisOSProcessAccessor := self concreteClass basicNew initialize

]

{ #category : #'initialize-release' }
OSProcessAccessor class >> initialize [

	"OSProcessAccessor initialize"

	UseIOHandle := (Smalltalk hasClassNamed: #IOHandle).
	ThisOSProcessAccessor := nil.
	self emulateWin32FileLocking: false.
	self allSubInstances do: [:e | e finalize]

]

{ #category : #'platform identification' }
OSProcessAccessor class >> isResponsibleForThisPlatform [
	"Answer true if an instance of this class is responsible for representing the
	OS process for the Squeak VM running on the current platform."

	^ self subclassResponsibility
]

{ #category : #'instance creation' }
OSProcessAccessor class >> new [

	self inform: 'use OSProcessAccessor>>forThisOSProcess to create or obtain the OSProcess instance for this Smalltalk session.'.
	^ nil
]

{ #category : #'plugin identification' }
OSProcessAccessor >> aioModuleName [
	"Answer a string containing the module name string for the AIO plugin."

	"OSProcess accessor aioModuleName"

	^ self subclassResponsibility
]

{ #category : #'plugin identification' }
OSProcessAccessor >> aioVersionString [
	"Answer a string containing the version string for the AIO plugin."

	"OSProcess accessor aioVersionString"

	^ self subclassResponsibility
]

{ #category : #testing }
OSProcessAccessor >> canAccessSystem [
	"Answer true if it is possible to access the external process. Concrete subclasses should
	know how to answer true."

	^ false

]

{ #category : #'file lock registry' }
OSProcessAccessor >> canAcquireLock: anOSFileLockDescriptor [
	"Answer true if the file lock cache will permit fileLock to be acquired. This method
	does not guarantee that the underlying OS will grant the lock."

	^ (self fileLockRegistry anySatisfy:
			[:ld | ld isActive and: [ld conflictsWith: anOSFileLockDescriptor]]) not
]

{ #category : #testing }
OSProcessAccessor >> canForwardExternalSignals [
	"Answer true if it is possible to forward OS signals to a Smalltalk Semaphore."

	^ false

]

{ #category : #accessing }
OSProcessAccessor >> canObtainSessionIdentifierFromPlugin [

	^ canObtainSessionIdentifierFromPlugin
		ifNil: [canObtainSessionIdentifierFromPlugin := self primGetSession notNil]
]

{ #category : #'file lock registry' }
OSProcessAccessor >> emulateWin32FileLocking [
	"Answer the current value of this preference"

	^ EmulateWin32FileLocking
]

{ #category : #'file lock registry' }
OSProcessAccessor >> fileLockRegistry [

	^ FileLockRegistry ifNil: [FileLockRegistry := Set new]

]

{ #category : #'session identification' }
OSProcessAccessor >> getSessionIdentifier [
	"Call a primitive to obtain the unique identifier for this Squeak session. If the
	primitive fails, try to deduce the session identifier from an instance of
	StandardFileStream. Some versions of the OSProcessPlugin may not be able to
	obtain a session ID, so this provides a mechanism for obtaining the session ID
	indirectly if necessary."

	"OSProcess accessor getSessionIdentifier"

	| session |
	session := self primGetSession.
	session ifNil: [session :=  self getSessionIdentifierFromSourcesFile].
	session ifNil: [session :=  self getSessionIdentifierFromFileInSqueakDirectory].
	^ session

]

{ #category : #'session identification' }
OSProcessAccessor >> getSessionIdentifierFromFileInSqueakDirectory [
	"Deduce the session identifier using method of last resort.
	This is an unreliable method, because it assumes knowledge of the internal structure
	of the SQFile data structure.

	Deprecated:
	As of approximately Squeak 3.8 and beyond, the session id has been moved to the
	first slot of the data structure. This method will not work for a Squeak VM beyond
	that point, and will not work for any 64 bit VM. However, an reliable means of
	obtaining sessionID is now available (#getSessionIdentifier), so this method is retained
	only for backwards compatibility to allow OSPP to be built on an older VMMaker."

	"OSProcess accessor getSessionIdentifierFromFileInSqueakDirectory"

	| id s |
	(OSProcess directoryEntryNames: OSProcess defaultPathString) do:
		[:n | (s := FileStream readOnlyFileNamed: n) ifNotNil:
			[(Smalltalk hasClassNamed: #IOHandle)
				ifTrue: [id := s ioHandle getHandle copyFrom: 5 to: 8]
				ifFalse: [(id := s fileID) ifNotNil: [id copyFrom: 5 to: 8]].
			s close.
			^ id]].
	^ nil

]

{ #category : #'session identification' }
OSProcessAccessor >> getSessionIdentifierFromSourcesFile [
	"Deduce the session identifier from an existing open FileStream on the sources file.
	This is an unreliable method, because it assumes knowledge of the internal structure
	of the SQFile data structure.

	Deprecated:
	As of approximately Squeak 3.8 and beyond, the session id has been moved to the
	first slot of the data structure. This method will not work for a Squeak VM beyond
	that point, and will not work for any 64 bit VM. However, an reliable means of
	obtaining sessionID is now available (#getSessionIdentifier), so this method is retained
	only for backwards compatibility to allow OSPP to be built on an older VMMaker."

	"OSProcess accessor getSessionIdentifierFromSourcesFile"

	| s id |
	s := SourceFiles first.
	s ifNil: [^ nil].
	^ (Smalltalk hasClassNamed: #IOHandle)
		ifTrue: [s ioHandle getHandle copyFrom: 5 to: 8]
		ifFalse: [(id := s fileID) ifNotNil: [id copyFrom: 5 to: 8]]

]

{ #category : #'standard IO handles' }
OSProcessAccessor >> getStdErrHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard error for the
	OS process in which I am currently executing."

	^ self subclassResponsibility

]

{ #category : #'standard IO handles' }
OSProcessAccessor >> getStdInHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard input for the
	OS process in which I am currently executing."

	^ self subclassResponsibility

]

{ #category : #'standard IO handles' }
OSProcessAccessor >> getStdOutHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard output for the
	OS process in which I am currently executing."

	^ self subclassResponsibility

]

{ #category : #accessing }
OSProcessAccessor >> grimReaper [
	"Answer the value of grimReaper"

	^ grimReaper
]

{ #category : #accessing }
OSProcessAccessor >> grimReaper: anObject [
	"Set the value of grimReaper"

	grimReaper := anObject
]

{ #category : #'private - IOHandle' }
OSProcessAccessor >> handleFromAccessor: aByteArrayOrIOAccessor [

	UseIOHandle
		ifTrue: [aByteArrayOrIOAccessor isNil
			ifTrue: [^ nil]
			ifFalse: [^ aByteArrayOrIOAccessor asSQFileStruct]]
		ifFalse: [^ aByteArrayOrIOAccessor]
]

{ #category : #'private - IOHandle' }
OSProcessAccessor >> handleFromFileStream: aFileStream [

	^ UseIOHandle
		ifTrue: [self handleFromAccessor: aFileStream ioHandle]
		ifFalse: [aFileStream fileID]

]

{ #category : #testing }
OSProcessAccessor >> handlesOsSignals [
	"True if OS signals can be handled and forwarded to the image"

	^ false
]

{ #category : #'initialize - release' }
OSProcessAccessor >> initialize [

	canObtainSessionIdentifierFromPlugin := nil.
	self canObtainSessionIdentifierFromPlugin.
	sessionIdentifier := nil.
	self sessionIdentifier.

]

{ #category : #'private - IOHandle' }
OSProcessAccessor >> ioAccessorFromSQFile: aByteArray [
	"Answer an object which represents an IO channel. If IOHandle is present in
	this image, use it; otherwise just answer aByteArray."

	UseIOHandle
		ifTrue: [^ (Smalltalk at: #IOHandle) newFromSqFileStruct: aByteArray]
		ifFalse: [^ aByteArray]
]

{ #category : #'file testing' }
OSProcessAccessor >> isAtEndOfFile: anIOHandle [
	"Answer whether the file represented by anIOHandle is at end of file, as determined
	by a call to feof(). This is different from StandardFileStream>>primAtEnd: which answers
	true if the file pointer is at the end of the file, but which does not call feof() to
	determine that an end of file condition has occurred. The difference is significant
	if aSqFileStruct represents a pipe or a device file, which may not be positionable
	in the sense of a conventional disk file."

	^ self primTestEndOfFileFlag: (self handleFromAccessor: anIOHandle)

]

{ #category : #'platform identification' }
OSProcessAccessor >> isResponsibleForThisPlatform [
	"Answer true is this is an instance of the class which is responsible for representing
	the OS process for the Squeak VM running on the current platform. A false answer is
	usually the result of running the image on a different platform and VM."

	^ self class isResponsibleForThisPlatform
]

{ #category : #'pipe open' }
OSProcessAccessor >> makePipeHandles [
	"Create a pipe, and answer an array of two IO accessors for the pipe 
	reader and writer."

	"OSProcess accessor makePipeHandles"

	^self primCreatePipe
		ifNotNilDo: [:p | ^ p collect: [:e | self ioAccessorFromSQFile: e]]

]

{ #category : #'initialize - release' }
OSProcessAccessor >> newPid [
	"This image is now being run in a new VM process with different pid. Pause the handling
	of child processes, and remove references to child processes that no longer pertain to
	the current VM process."

	grimReaper ifNotNilDo: [ :p | p terminate. grimReaper := nil ].
	self changed: #pid.
	self restartChildWatcherProcess
]

{ #category : #'plugin identification' }
OSProcessAccessor >> osppModuleName [
	"Answer a string containing the module name string for the OSPP plugin."

	"OSProcess accessor osppModuleName"

	^ self subclassResponsibility
]

{ #category : #'plugin identification' }
OSProcessAccessor >> osppModuleVersionString [
	"Answer a string containing the version string for the OSPP plugin."

	"OSProcess accessor osppModuleVersionString"

	^ self subclassResponsibility
]

{ #category : #'session identification' }
OSProcessAccessor >> primGetSession [
	"Subclasses should override if they know how to obtain the session identifier."

	^ nil
]

{ #category : #'file testing' }
OSProcessAccessor >> primTestEndOfFileFlag: aSqFileStruct [
	"Answer whether the file represented by aSqFileStruct is at end of file, as determined
	by a call to feof(). This is different from StandardFileStream>>primAtEnd: which answers
	true if the file pointer is at the end of the file, but which does not call feof() to
	determine that an end of file condition has occurred. The difference is significant
	if aSqFileStruct represents a pipe or a device file, which may not be positionable
	in the sense of a conventional disk file."

	^ self subclassResponsibility

]

{ #category : #'file lock registry' }
OSProcessAccessor >> register: fileRegionLock [
	"If an object equal to fileRegionLock exists in the registry, answer it. Otherwise, add
	fileRegionLock to the registry and answer fileRegionLock."

	^ (self fileLockRegistry like: fileRegionLock)
		ifNil: [self fileLockRegistry add: fileRegionLock]

]

{ #category : #'file lock registry' }
OSProcessAccessor >> registeredLocksForFile: aFileStream [
	"Answer all lock descriptors associated with aFileStream"

	^ self fileLockRegistry select: [:ea | ea fileStream = aFileStream]

]

{ #category : #'file lock registry' }
OSProcessAccessor >> removeInactiveLocks [
	"Go through the lock cache and remove any that have been left
	behind after their streams were closed."

	^ self fileLockRegistry copy do: [:ea | ea isActive ifFalse: [self fileLockCache remove: ea]]
]

{ #category : #'initialize - release' }
OSProcessAccessor >> restartChildWatcherProcess [
	self subclassResponsibility
]

{ #category : #accessing }
OSProcessAccessor >> sessionIdentifier [

	^ sessionIdentifier ifNil: [sessionIdentifier := self getSessionIdentifier]

]

{ #category : #'file control' }
OSProcessAccessor >> setNonBlocking: anIOHandle [
	"Convert anIOHandle to an SQFile data structure and call primitive to set it non-blocking."

	^ self subclassResponsibility

]

{ #category : #'file lock registry' }
OSProcessAccessor >> unregister: fileRegionLock [
	"If an object equal to fileRegionLock exists in the registry, remove it and
	answer the object. Otherwise answer nil."


	^ self fileLockRegistry remove: fileRegionLock ifAbsent: [nil]

]

{ #category : #'plugin identification' }
OSProcessAccessor >> xdcpModuleName [
	"Answer a string containing the module name string for the display control plugin."

	"OSProcess accessor xdcpModuleName"

	^ self subclassResponsibility
]

{ #category : #'plugin identification' }
OSProcessAccessor >> xdcpVersionString [
	"Answer a string containing the version string for the display control plugin."

	"OSProcess accessor xdcpVersionString"

	^ self subclassResponsibility
]
