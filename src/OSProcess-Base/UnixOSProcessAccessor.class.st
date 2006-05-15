"
I provide access to the operating system process in which the Squeak VM is currently running. I am based on the Unix process model. There is only one instance of me, and instances of UnixOSProcess depend on me to provide access to the operating system process which they represent.

I know how to create child processes. I use a semaphore to receive signals when child processes die, and I notify my dependents (instances of UnixOSProcess) when these events occur.


"
Class {
	#name : #UnixOSProcessAccessor,
	#superclass : #OSProcessAccessor,
	#instVars : [
		'grimReaper',
		'sigChldSemaphore'
	],
	#classVars : [
		'ThisProcessPid'
	],
	#category : #'OSProcess-Unix'
}

{ #category : #'platform identification' }
UnixOSProcessAccessor class >> isResponsibleForThisPlatform [
	"Answer true if this class is responsible for representing the OS process for the
	Squeak VM running on the current platform."

	^ OSProcess isUnix

]

{ #category : #'plugin identification' }
UnixOSProcessAccessor >> aioModuleName [
	"Answer a string containing the module name string for the AIO plugin."

	"OSProcess accessor aioModuleName"

	^ self primAioPluginModuleName

]

{ #category : #'plugin identification' }
UnixOSProcessAccessor >> aioVersionString [
	"Answer a string containing the version string for the AIO plugin."

	"OSProcess accessor aioVersionString"

	^ self primAioPluginVersionString

]

{ #category : #testing }
UnixOSProcessAccessor >> canAccessChildProcess: anExternalProcess [
	"Is the child process still there? Maybe not if we have restarted the image
	and anExternalProcess refers to a process which died while we were not
	watching."

	^ self primCanReceiveSignals: anExternalProcess pid
]

{ #category : #testing }
UnixOSProcessAccessor >> canAccessSystem [
	"Answer true if it is possible to access the external process, else false. Failure
	to access the external process is probably due to lack of a UnixOSProcessPlugin
	module."

	^ self primGetPid notNil

]

{ #category : #testing }
UnixOSProcessAccessor >> canControlXDisplay [
	"True if the XDisplayControlPlugin is accessible. Older versions of OSProcess relied on
	the X display control to be embedded in the OSProcessPlugin module. This has been
	moved to a separate display control plugin to allow support of non-X platforms and
	other display media on Unix platforms (OS X)."

	"OSProcess accessor canControlXDisplay"

	^ self primXDisplayControlPluginModuleName notNil

]

{ #category : #testing }
UnixOSProcessAccessor >> canForwardExternalSignals [
	"Answer true if it is possible to forward OS signals to a Smalltalk Semaphore."

	^ true

]

{ #category : #'external process access' }
UnixOSProcessAccessor >> chDir: pathString [
	"Change current working directory. The $PWD environment variable is not updated (but
	see UnixProcess>>chDir:). Answer nil for success, or an error message."

	"OSProcess accessor chDir: '/tmp'"
	"OSProcess accessor chDir: '/no/such/path'"
	"OSProcess accessor chDir: FileDirectory default name"

	| result message |
	result _ self primChdir: pathString.
	result isNil
		ifTrue:
			[^ nil]
		ifFalse:
			[message _ self primErrorMessageAt: result.
			^ message]

]

{ #category : #'external process access' }
UnixOSProcessAccessor >> environmentAt: aSymbolOrString [
	"Get an environment variable from the external OS process."

	"OSProcess thisOSProcess environmentAt: 'PATH'"

	^ self primEnvironmentAtSymbol: aSymbolOrString

]

{ #category : #'external process access' }
UnixOSProcessAccessor >> environmentAt: aSymbolOrString put: aString [
	"Add or update an environment variable in the external OS process. Convert aSymbol
	and aString into a KEY=value string and pass this to the OS process environment.
	Standard C libraries provide a putenv() function for this purpose, with a parameter
	in the form KEY=value. Note: Maintain a reference to the return value, see note in
	primitivePutEnv."

	"OSProcess accessor environmentAt: 'AAAA' put: 'this is the value of AAAA'"
	"OSProcess accessor environmentAt: 'AAAA' put: nil"
	"OSProcess accessor environmentAt: 'AAAA'"

	aString isNil
		ifTrue:
			[^ self primUnsetEnv: aSymbolOrString, (Character value: 0) asString]
		ifFalse:
			[^ self environmentPut: (aSymbolOrString asString, '=', aString)]

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> environmentPut: aString [
	"Add or update an environment variable in the external OS process using a 'KEY=value'
	string. Create a null terminated string for use by the external putenv() call in a pluggable
	primitive."

	"OSProcess thisOSProcess processAccessor environmentPut: 'SOMEKEY=somevalue'"

	| cString |
	cString _ aString, (Character value: 0) asString.
	^ self primPutEnv: cString

]

{ #category : #'file testing' }
UnixOSProcessAccessor >> fileProtectionMask: aPathString [
	"Call stat(2) to obtain the file protection mask for a file."

	"OSProcess accessor fileProtectionMask: '/bin/sh'"
	"OSProcess accessor fileProtectionMask: '/etc/hosts'"
	"OSProcess accessor fileProtectionMask: '/bin/su'"
	"OSProcess accessor fileProtectionMask: '/bin/NOSUCHFILE'"
	"OSProcess accessor fileProtectionMask: 12345"

	| mask |
	(aPathString isKindOf: String) ifFalse: [self error: 'expected a path string'. ^ nil].
	mask _ self primFileProtectionMask: aPathString.
	(mask == nil) ifTrue: [^ nil].
	(mask isKindOf: Integer)
		ifTrue: [^ self primErrorMessageAt: mask].
	^ mask

]

{ #category : #'file testing' }
UnixOSProcessAccessor >> fileStat: aPathString [
	"Call stat(2) to obtain the UID, GID, and file protection mask for a file."

	"OSProcess accessor fileStat: '/var/spool/news'"
	"OSProcess accessor fileStat: '/etc/hosts'"
	"OSProcess accessor fileStat: '/bin/su'"
	"OSProcess accessor fileStat: '/bin/NOSUCHFILE'"
	"OSProcess accessor fileStat: 12345"

	| mask |
	(aPathString isKindOf: String) ifFalse: [self error: 'expected a path string'. ^ nil].
	mask _ self primFileStat: aPathString.
	(mask == nil) ifTrue: [^ nil].
	(mask isKindOf: Integer)
		ifTrue: [^ self primErrorMessageAt: mask].
	^ mask

]

{ #category : #'initialize - release' }
UnixOSProcessAccessor >> finalize [
	"Clean up grimReaper and associated semaphore."

	self grimReaper ifNotNil:
			[grimReaper terminate.
			grimReaper _ nil].
	self sigChldSemaphore ifNotNil:
			[self restoreSignal: self primSigChldNumber.
			self sigChldSemaphore: nil]

]

{ #category : #'file control' }
UnixOSProcessAccessor >> flushExternalStream: anIOHandle [
	"Convert anIOHandle to an SQFile data structure and call primitive to flush the
	external I/O stream."

	^ self canObtainSessionIdentifierFromPlugin
		ifTrue: [self primSQFileFlush: (self handleFromAccessor: anIOHandle)]
		ifFalse: [self primSQFileFlush: (self handleFromAccessor: anIOHandle) withSessionIdentifier: self sessionIdentifier]

]

{ #category : #'fork and exec' }
UnixOSProcessAccessor >> forkAndExec: executableFile
	stdIn: inputFileHandle
	stdOut: outputFileHandle
	stdErr: errorFileHandle
	argBuf: argVec
	argOffsets: argOffsets
	envBuf: envVec
	envOffsets: envOffsets
	workingDir: pathString [

	"Parameters are expected to have been properly prepared by the caller, including string
	values which are to be null terminated strings. In other words, all strings should have
	(Character value: 0) as the last element in the string.

	Parameters should be:
		executableFile: a string with the name of a file to execute.
		stdIn: a fileID ByteArray (struct SQFile in C) to be used as standard input.
		stdOut: a fileID ByteArray to be used as standard output.
		stdErr: a fileID ByteArray to be used as standard error.
		argVec: a String arranged to look more or less like a char **, but with the addresses not yet fixed.
		argOffsets: an Array of offsets for fixing up the argVec addresses.
		envVec: a String arranged to look more or less like a char **, but with the addresses not yet fixed.
		envOffsets: an Array of offsets for fixing up the envVec addresses.
		workingDir: a null terminated path name String, or nil.
	The envVec parameter may be nil, in which case envOffsets is ignored. workingDir may be nil. The
	other parameters are required. Parameters with nil value indicate that current values for this process
	should be used."

	^ self primForkExec: executableFile
			stdIn: inputFileHandle
			stdOut: outputFileHandle
			stdErr: errorFileHandle
			argBuf: argVec
			argOffsets: argOffsets
			envBuf: envVec
			envOffsets: envOffsets
			workingDir: pathString

]

{ #category : #'fork and exec' }
UnixOSProcessAccessor >> forkSqueak [
	"Clone this Squeak Smalltalk image in a child OSProcess. The child is the same as the
	parent, except for its new X session connection, and the return value of this method,
	which is zero for the child process, and a positive integer equal to the pid of the child
	for the parent process.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	^ self primForkSqueak

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigChld [
	"Set a signal handler for SIGCHLD. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigChld"

	^ self forwardSignal: self primSigChldNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigHup [
	"Set a signal handler for SIGHUP. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigHup"

	^ self forwardSignal: self primSigHupNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigInt [
	"Set a signal handler for SIGINT. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigInt"

	^ self forwardSignal: self primSigIntNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigKill [
	"Set a signal handler for SIGKILL. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigKill"

	self notify: 'SIGKILL and SIGSTOP signals cannot be caught, see man signal(2)'.
	^ self forwardSignal: self primSigKillNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigPipe [
	"Set a signal handler for SIGPIPE. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigPipe"

	^ self forwardSignal: self primSigPipeNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigQuit [
	"Set a signal handler for SIGQUIT. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigQuit"

	^ self forwardSignal: self primSigQuitNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigTerm [
	"Set a signal handler for SIGTERM. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigTerm"

	^ self forwardSignal: self primSigTermNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigUsr1 [
	"Set a signal handler for SIGUSR1. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigUsr1"

	^ self forwardSignal: self primSigUsr1Number

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSigUsr2 [
	"Set a signal handler for SIGUSR2. Answer a new Semaphore, or nil if unable
	to set the handler (possibly because it has already been set)."

	"OSProcess accessor forwardSigUsr1"

	^ self forwardSignal: self primSigUsr2Number

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> forwardSignal: signalNumber [ 
	"Set a signal handler in the VM which will signal a Smalltalk semaphore 
	at semaphoreIndex whenever an external signal sigNum is received.
	Answer a new Semaphore, or nil if unable to set the handler (possibly
	because it has already been set). A Smalltalk process can wait on the
	Semaphore, and take action when a signal is detected. See man(7) signal
	for signal number definitions on your unix system."

	"OSProcess accessor forwardSignal: OSProcess accessor primSigIntNumber"

	| sema index |
	sema _ Semaphore new.
	index _ Smalltalk registerExternalObject: sema.
	(self primForwardSignal: signalNumber toSemaphore: index)
		ifNil:
			[Smalltalk unregisterExternalObject: sema.
			^ nil].
	^ sema
]

{ #category : #'standard IO handles' }
UnixOSProcessAccessor >> getStdErrHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard error for the
	OS process in which I am currently executing."

	| handle |
	handle _ self canObtainSessionIdentifierFromPlugin
		ifTrue: [handle _ self primGetStdErrHandle]
		ifFalse: [handle _ self primGetStdErrHandleWithSessionIdentifier: self sessionIdentifier].
	handle ifNil: [^ nil].
	^ self ioAccessorFromSQFile: handle

]

{ #category : #'standard IO handles' }
UnixOSProcessAccessor >> getStdInHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard input for the
	OS process in which I am currently executing."

	| handle |
	handle _ self canObtainSessionIdentifierFromPlugin
		ifTrue: [handle _ self primGetStdInHandle]
		ifFalse: [handle _ self primGetStdInHandleWithSessionIdentifier: self sessionIdentifier].
	handle ifNil: [^ nil].
	^ self ioAccessorFromSQFile: handle

]

{ #category : #'standard IO handles' }
UnixOSProcessAccessor >> getStdOutHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard output for the
	OS process in which I am currently executing."

	| handle |
	handle _ self canObtainSessionIdentifierFromPlugin
		ifTrue: [handle _ self primGetStdOutHandle]
		ifFalse: [handle _ self primGetStdOutHandleWithSessionIdentifier: self sessionIdentifier].
	handle ifNil: [^ nil].
	^ self ioAccessorFromSQFile: handle

]

{ #category : #accessing }
UnixOSProcessAccessor >> grimReaper [
	"Answer the value of grimReaper"

	^ grimReaper
]

{ #category : #accessing }
UnixOSProcessAccessor >> grimReaper: anObject [
	"Set the value of grimReaper"

	grimReaper _ anObject
]

{ #category : #'initialize - release' }
UnixOSProcessAccessor >> grimReaperProcess [
	"This is a process which waits for the death of a child OSProcess, and 
	informs any dependents of the change. Use SIGCHLD events if possible,
	otherwise a Delay to poll for exiting child processes."

	| event processSynchronizationDelay |
	^ self canAccessSystem
		ifTrue:
			[event _ (self canAccessSystem and: [self canForwardExternalSignals])
				ifTrue: [self sigChldSemaphore]
				ifFalse: [Delay forMilliseconds: 200].
			processSynchronizationDelay _ Delay forMilliseconds: 20.
			grimReaper ifNil:
				[grimReaper _
					[[event wait.
					processSynchronizationDelay wait. "Avoids lost signals in heavy process switching"
					self changed: #childProcessStatus] repeat] fork]]
		ifFalse:
			[nil]

]

{ #category : #testing }
UnixOSProcessAccessor >> handlesOsSignals [
	"True if OS signals can be handled and forwarded to the image"

	^ true
]

{ #category : #'initialize - release' }
UnixOSProcessAccessor >> initialize [
	"Call this method when an instance is first created, or to refresh after an image
	restart to clean up from the previous session. Notify dependents of my singleton
	instance if the image has restarted in a different OS process (this is not the case
	when #startUp is called after a simple image save)."

	self finalize.
	super initialize.
	self sigChldSemaphore.
	self grimReaperProcess.
	ThisProcessPid ~~ self primGetPid
		ifTrue: 
			["Image has been restarted and is now running in a different OS process"
			ThisProcessPid _ self primGetPid.
			self changed: #startUp].
	self changed

]

{ #category : #'file testing' }
UnixOSProcessAccessor >> isAtEndOfFile: anIOHandle [
	"Answer whether the file represented by anIOHandle is at end of file, as determined
	by a call to feof(). This is different from StandardFileStream>>primAtEnd: which answers
	true if the file pointer is at the end of the file, but which does not call feof() to
	determine that an end of file condition has occurred. The difference is significant
	if aSqFileStruct represents a pipe or a device file, which may not be positionable
	in the sense of a conventional disk file."

	| atEof |
	atEof _ self primTestEndOfFileFlag: (self handleFromAccessor: anIOHandle).
	atEof ifNil: [self error: 'unsupported primitive, plugin may be out of date'].
	^ atEof isNil or: [atEof]

]

{ #category : #'file testing' }
UnixOSProcessAccessor >> isExecutable: aPathName [
	"Answer true if file at aPathName has execute permission for this process."

	"OSProcess accessor isExecutable: '/bin/sh'"
	"OSProcess accessor isExecutable: '/no/such/file'"

	^ self isExecutable: aPathName forUser: self primGetUid inGroup: self primGetGid


]

{ #category : #'file testing' }
UnixOSProcessAccessor >> isExecutable: aPathName forUser: uid inGroup: gid [
	"Answer true if file at aPathName has execute permission for a user
	identified by user uid and group gid."

	"OSProcess accessor
		isExecutable: '/bin/sh'
		forUser: OSProcess accessor primGetUid
		inGroup: OSProcess accessor primGetGid"

	| fStat suid sgid user group protectionMask |
	fStat _ self fileStat: aPathName.
	(fStat isKindOf: String)
		ifTrue: [self inform: aPathName, ': ', fStat. ^ nil].
	protectionMask _ fStat at: 3.
	((protectionMask at: 4) allMask: 1)
		ifTrue: [^ true]. "Test executable by any user ID"
	sgid _ (protectionMask at: 1) allMask: 2.
	sgid
		ifTrue: [group _ gid]
		ifFalse: [group _ fStat at: 2].
	((gid == group) and: [(protectionMask at: 3) allMask: 1])
		ifTrue: [^ true]. "Test executable by my group ID"
	suid _ (protectionMask at: 1) allMask: 4.
	suid
		ifTrue: [user _ uid]
		ifFalse: [user _ fStat at: 1].
	((uid == user) and: [(protectionMask at: 2) allMask: 1])
		ifTrue: [^ true]. "Test executable by my user ID"
	^ false


]

{ #category : #'file locking' }
UnixOSProcessAccessor >> isLockableFile: aFileStream [
	"Check for ability to place an exclusive lock on the entire file represented by
	aFileStream. An exclusive lock (write lock) permits only one OS process to hold
	the lock. Answer true if the region is lockable."

	^ self isLockableFile: aFileStream exclusive: true

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> isLockableFile: aFileStream exclusive: flag [
	"Check for ability to place an exclusive lock on the entire file represented by
	aFileStream. An exclusive lock (write lock) permits only one OS process to hold
	the lock. Answer true if the region is lockable."

	| fileLock |
	aFileStream ifNil: [^ false].
	fileLock _ OSFileLock onFile: aFileStream exclusive: flag.
	^ self isLockableFileRegion: fileLock

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> isLockableFile: aFileStream from: start to: end [
	"Pass a struct SQFile on the stack, and check for ability to lock the specified region.
	If the exclusive flag is true, then specify an exclusive (F_WRLCK) lock on the
     file. Otherwise, specify a shared (F_RDLCK) lock. Any number of Unix processes
     may hold  a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock).

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Answer true if the region is lockable."

	^ self isLockableFile: aFileStream from: start to: end exclusive: true

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> isLockableFile: aFileStream from: start to: end exclusive: flag [
	"Pass a struct SQFile on the stack, and check for ability to lock the specified region.
	If the exclusive flag is true, then specify an exclusive (F_WRLCK) lock on the
     file. Otherwise, specify a shared (F_RDLCK) lock. Any number of Unix processes
     may hold  a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock).

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Answer true if the region is lockable."

	| fileRegion |
	aFileStream ifNil: [^ false].
	fileRegion _ OSFileRegionLock onFile: aFileStream from: start to: end exclusive: flag.
	^ self isLockableFileRegion: fileRegion

]

{ #category : #deprecated }
UnixOSProcessAccessor >> isLockableFile: aFileStream region: anInterval [
	"Pass a struct SQFile on the stack, and check for ability to place an exclusive
	lock on the specified region. An exclusive lock (write lock) permits only one
	OS process to hold the lock. Answer true if the region is lockable.

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file."

	^ self isLockableFile: aFileStream region: anInterval exclusive: true

]

{ #category : #deprecated }
UnixOSProcessAccessor >> isLockableFile: aFileStream region: anInterval exclusive: flag [
	"Pass a struct SQFile on the stack, and check for ability to lock the specified region.
	If the exclusive flag is true, then specify an exclusive (F_WRLCK) lock on the
     file. Otherwise, specify a shared (F_RDLCK) lock. Any number of Unix processes
     may hold  a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock).

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Answer true if the region is lockable."

	| fileRegion |
	aFileStream ifNil: [^ false].
	fileRegion _ OSFileRegionLock onFile: aFileStream interval: anInterval exclusive: flag.
	^ self isLockableFileRegion: fileRegion

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> isLockableFileRegion: aFileLock [
	"Pass a struct SQFile on the stack, and check for ability to lock the specified region.
	If the exclusive flag is true, then specify an exclusive (F_WRLCK) lock on the
     file. Otherwise, specify a shared (F_RDLCK) lock. Any number of Unix processes
     may hold  a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock).

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Answer true if the region is lockable."

	aFileLock ifNil: [^ false].
	(self canAcquireLock: aFileLock) ifFalse: [^ false].
	
	^ aFileLock test

]

{ #category : #'file testing' }
UnixOSProcessAccessor >> isReadable: aPathName [
	"Answer true if file at aPathName has read permission for this process."

	"OSProcess accessor isWritable: '/bin/sh'"

	^ self isReadable: aPathName forUser: self primGetUid inGroup: self primGetGid


]

{ #category : #'file testing' }
UnixOSProcessAccessor >> isReadable: aPathName forUser: uid inGroup: gid [
	"Answer true if file at aPathName has read permission for a user
	identified by user uid and group gid."

	"OSProcess accessor
		isReadable: '/bin/sh'
		forUser: OSProcess accessor primGetUid
		inGroup: OSProcess accessor primGetGid"

	| fStat user group protectionMask |
	fStat _ self fileStat: aPathName.
	(fStat isKindOf: String)
		ifTrue: [self inform: aPathName, ': ', fStat. ^ nil].
	protectionMask _ fStat at: 3.
	((protectionMask at: 4) allMask: 4)
		ifTrue: [^ true]. "Test readable by any user ID"
	group _ fStat at: 2.
	((gid == group) and: [(protectionMask at: 3) allMask: 4])
		ifTrue: [^ true]. "Test readable by my group ID"
	user _ fStat at: 1.
	((uid == user) and: [(protectionMask at: 2) allMask: 4])
		ifTrue: [^ true]. "Test readable by my user ID"
	^ false


]

{ #category : #'file testing' }
UnixOSProcessAccessor >> isWritable: aPathName [
	"Answer true if file at aPathName has write permission for this process."

	"OSProcess accessor isWritable: '/bin/sh'"

	^ self isWritable: aPathName forUser: self primGetUid inGroup: self primGetGid


]

{ #category : #'file testing' }
UnixOSProcessAccessor >> isWritable: aPathName forUser: uid inGroup: gid [
	"Answer true if file at aPathName has read permission for a user
	identified by user uid and group gid."

	"OSProcess accessor
		isWritable: '/bin/sh'
		forUser: OSProcess accessor primGetUid
		inGroup: OSProcess accessor primGetGid"

	| fStat user group protectionMask |
	fStat _ self fileStat: aPathName.
	(fStat isKindOf: String)
		ifTrue: [self inform: aPathName, ': ', fStat. ^ nil].
	protectionMask _ fStat at: 3.
	((protectionMask at: 4) allMask: 2)
		ifTrue: [^ true]. "Test writable by any user ID"
	group _ fStat at: 2.
	((gid == group) and: [(protectionMask at: 3) allMask: 2])
		ifTrue: [^ true]. "Test writable by my group ID"
	user _ fStat at: 1.
	((uid == user) and: [(protectionMask at: 2) allMask: 2])
		ifTrue: [^ true]. "Test writable by my user ID"
	^ false


]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFile: aFileStream [
	"Request an exclusive lock on the entire file represented by aFileStream. The
	exclusive lock (write lock) permits only one OS process to hold the lock. Answer
	a descriptor for the locked file region, an Array of file handle and region interval;
	or answer nil on error.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self lockFile: aFileStream exclusive: true

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFile: aFileStream exclusive: flag [
	"Request an exclusive lock on the entire file represented by aFileStream. The
	exclusive lock (write lock) permits only one OS process to hold the lock. Answer
	a descriptor for the locked file region, an Array of file handle and region interval;
	or answer nil on error.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self lockFile: aFileStream exclusive: flag ifFail: nil

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFile: aFileStream exclusive: flag ifFail: failBlock [
	"Request an exclusive lock on the entire file represented by aFileStream. The
	exclusive lock (write lock) permits only one OS process to hold the lock. Answer
	a descriptor for the locked file region, an Array of file handle and region interval;
	or answer nil on error.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	| fileLock |
	aFileStream ifNil: [^ failBlock value].
	fileLock _ OSFileLock onFile: aFileStream exclusive: flag.
	^ self lockFileRegion: fileLock ifFail: failBlock

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFile: aFileStream from: start to: end [
	"Pass a struct SQFile on the stack, and request a lock on the specified region.
	If the exclusive flag is true, then request an exclusive (F_WRLCK) lock on the
     file. Otherwise, request a shared (F_RDLCK) lock. Any number of Unix processes
     may hold a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock). Answer a descriptor for the locked file region,
	an Array of file handle and region interval; or answer nil on error.

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self lockFile: aFileStream from: start to: end exclusive: true

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFile: aFileStream from: start to: end exclusive: flag [
	"Pass a struct SQFile on the stack, and request a lock on the specified region.
	If the exclusive flag is true, then request an exclusive (F_WRLCK) lock on the
     file. Otherwise, request a shared (F_RDLCK) lock. Any number of Unix processes
     may hold a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock). Answer a descriptor for the locked file region,
	an Array of file handle and region interval; or answer nil on error.

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	| fileRegion |
	aFileStream ifNil: [^ nil].
	fileRegion _ OSFileRegionLock onFile: aFileStream from: start to: end exclusive: flag.
	^ self lockFileRegion: fileRegion

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFile: aFileStream ifFail: failBlock [
	"Request an exclusive lock on the entire file represented by aFileStream. The
	exclusive lock (write lock) permits only one OS process to hold the lock. Answer
	a descriptor for the locked file region, an Array of file handle and region interval;
	or answer nil on error.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self lockFile: aFileStream exclusive: true ifFail: failBlock

]

{ #category : #deprecated }
UnixOSProcessAccessor >> lockFile: aFileStream region: anInterval [
	"Pass a struct SQFile on the stack, and request an exclusive lock on the specified
	region. The exclusive lock (write lock) permits only one OS process to hold the lock.
	Answer a descriptor for the locked file region, an Array of file handle and region
	interval; or answer nil on error.

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self lockFile: aFileStream region: anInterval exclusive: true


]

{ #category : #deprecated }
UnixOSProcessAccessor >> lockFile: aFileStream region: anInterval exclusive: flag [
	"Pass a struct SQFile on the stack, and request a lock on the specified region.
	If the exclusive flag is true, then request an exclusive (F_WRLCK) lock on the
     file. Otherwise, request a shared (F_RDLCK) lock. Any number of Unix processes
     may hold a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock). Answer a descriptor for the locked file region,
	an Array of file handle and region interval; or answer nil on error.

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	| fileRegion |
	aFileStream ifNil: [^ nil].
	fileRegion _ OSFileRegionLock onFile: aFileStream interval: anInterval exclusive: flag.
	^ self lockFileRegion: fileRegion

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFileRegion: aFileLock [
	"Pass a struct SQFile on the stack, and request a lock on the specified region.
	If the exclusive flag is true, then request an exclusive (F_WRLCK) lock on the
     file. Otherwise, request a shared (F_RDLCK) lock. Any number of Unix processes
     may hold a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock). Answer a descriptor for the locked file region,
	an Array of file handle and region interval; or answer nil on error.

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self lockFileRegion: aFileLock ifFail: [nil]

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFileRegion: fileStream from: start to: end exclusive: writeLockFlag ifFail: failBlock [

	| lock |
	lock _ OSFileRegionLock onFile: fileStream from: start to: end exclusive: writeLockFlag.
	^ self lockFileRegion: lock ifFail: [failBlock value]
]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFileRegion: fileStream from: start to: end ifFail: failBlock [

	^ self lockFileRegion: fileStream from: start to: end exclusive: true ifFail: failBlock

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> lockFileRegion: aFileLock ifFail: failBlock [
	"Pass a struct SQFile on the stack, and request a lock on the specified region.
	If the exclusive flag is true, then request an exclusive (F_WRLCK) lock on the
     file. Otherwise, request a shared (F_RDLCK) lock. Any number of Unix processes
     may hold a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock). Answer a descriptor for the locked file region,
	an Array of file handle and region interval; or answer nil on error.

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	aFileLock ifNil: [^ failBlock value].
	"Check region lock overlap for Win32 compatibility"
	(self canAcquireLock: aFileLock) ifFalse: [^ failBlock value].
	
	aFileLock lock
		ifFalse: [^ failBlock value]
		ifTrue:
			[self register: aFileLock.
			^ aFileLock]

]

{ #category : #'pipe open' }
UnixOSProcessAccessor >> makePipeHandles [
	"Create a pipe, and answer an array of two IO accessors for the pipe 
	reader and writer. Set a signal handler to cause SIGPIPE signals to be
	ignored. This will register a Semaphore to receive the SIGPIPE events,
	but we will simply ignore the semaphore, effectively ignoring the
	external OS signals. This is done instead of explicitly telling the OS to
	ignore the signals because it allows the use of a uniform signal
	forwarding mechanism in Squeak, even for signals that are ultimately
	ignored."

	self forwardSigPipe.
	^ super makePipeHandles

]

{ #category : #'fork and exec' }
UnixOSProcessAccessor >> nice: inc [
	"Change the scheduling priority of this OS process by the given nice increment.
	A positive increment decreases the priority. Only the superuser can specify
	a negative value to increase the priority. A typical use is to increase the
	nice value by 1 in order to make the Squeak VM run at lower priority. This
	may be useful for a background Squeak doing an image save or other non-
	interactive process."

	"OSProcess accessor nice: 1"

	^ self primNice: inc

]

{ #category : #'display handling - old plugin compatibility' }
UnixOSProcessAccessor >> oldPrimCanConnectToXDisplay: xDisplayName [

	"Deprecated - install the XDisplayControlPlugin to eliminate the need to call this method"

	"Open and close a connection to displayName. It the connection was successfully
	opened, answer true; otherwise false. This is intended to check for the ability
	to open an X display prior to actually making the attempt."

	"OSProcess accessor primCanConnectToXDisplay: ':0.0' "
	"OSProcess accessor primCanConnectToXDisplay: ':1' "

	<primitive: 'primitiveCanConnectToXDisplay' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'display handling - old plugin compatibility' }
UnixOSProcessAccessor >> oldPrimGetXDisplayName [

	"Deprecated - install the XDisplayControlPlugin to eliminate the need to call this method"

	"Answer a string containing the name for the X display, or nil if the display was opened
	using the $DISPLAY environment variable. This answers the name of the X display as of
	the time it was last opened, which may be different from the current setting of $DISPLAY."

	"OSProcess accessor primGetXDisplayName"

	<primitive: 'primitiveGetXDisplayName' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'display handling - old plugin compatibility' }
UnixOSProcessAccessor >> oldPrimIsConnectedToXServer [

	"Deprecated - install the XDisplayControlPlugin to eliminate the need to call this method"

	"Answer true if VM is currently connected to an X server."

	"OSProcess accessor primIsConnectedToXServer inspect"
	"| x |
	OSProcess accessor primKillDisplay.
	x _ OSProcess accessor primIsConnectedToXServer.
	OSProcess accessor primOpenXDisplay.
	x inspect"

	<primitive: 'primitiveIsConnectedToXServer' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'display handling - old plugin compatibility' }
UnixOSProcessAccessor >> oldPrimKillDisplay [

	"Deprecated - install the XDisplayControlPlugin to eliminate the need to call this method"

	"Call an internal function which will disconnect the X display session."

	"OSProcess thisOSProcess processAccessor primKillDisplay"

	<primitive: 'primitiveKillDisplay' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'display handling - old plugin compatibility' }
UnixOSProcessAccessor >> oldPrimOpenXDisplay [

	"Deprecated - install the XDisplayControlPlugin to eliminate the need to call this method"

	"Call an internal function which will open the X display session."

	"OSProcess thisOSProcess processAccessor primKillDisplay.
	(Delay forSeconds: 5) wait.
	OSProcess thisOSProcess processAccessor primOpenXDisplay"

	<primitive: 'primitiveOpenXDisplay' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'display handling - old plugin compatibility' }
UnixOSProcessAccessor >> oldPrimSetXDisplayName: aStringOrNil [

	"Deprecated - install the XDisplayControlPlugin to eliminate the need to call this method"

	"Set the name for the X display for use in the next call to primitiveOpenXDisplay.
	aStringOrNil must be either a String (such as 'myhost:0') or nil, indicating that
	the current value of $DISPLAY should be used."

	"OSProcess accessor primSetXDisplayName: ':0.0' "
	"OSProcess accessor primSetXDisplayName: nil "

	<primitive: 'primitiveSetXDisplayName' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'plugin identification' }
UnixOSProcessAccessor >> osppModuleName [
	"Answer a string containing the module name string for the OSPP plugin."

	"OSProcess accessor osppModuleName"

	^ self primOSProcessPluginModuleName

]

{ #category : #'plugin identification' }
UnixOSProcessAccessor >> osppModuleVersionString [
	"Answer a string containing the version string for the OSPP plugin."

	"OSProcess accessor osppModuleVersionString"

	^ self primOSProcessPluginModuleVersionString

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primAioPluginModuleName [
	"Answer a string containing the module name string for the AIO plugin."

	"OSProcess accessor primAioPluginModuleName"

	<primitive: 'primitiveModuleName' module: 'AioPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primAioPluginVersionString [
	"Answer a string containing the version string for the AIO plugin."

	"OSProcess accessor primAioPluginVersionString"

	<primitive: 'primitiveVersionString' module: 'AioPlugin'>
	^ nil

]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primArgumentAt: index [
	"Answer the argument string in the argument OS process argument list at position index.
	In Unix, the first element of the list is the program name, and any additional elements
	of the list are optional command line arguments passed to the program. This convention
	may be simulated by the C runtime libraries on other operating systems, but argument
	list handling should be assumed to be operating system dependent."

	<primitive: 'primitiveArgumentAt' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primCanConnectToXDisplay: xDisplayName [
	"Open and close a connection to displayName. It the connection was successfully
	opened, answer true; otherwise false. This is intended to check for the ability
	to open an X display prior to actually making the attempt."

	"OSProcess accessor primCanConnectToXDisplay: ':0.0' "
	"OSProcess accessor primCanConnectToXDisplay: ':1' "

	<primitive: 'primitiveCanConnectToDisplay' module: 'XDisplayControlPlugin'>
	^ self oldPrimCanConnectToXDisplay: xDisplayName


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primCanReceiveSignals: anIntegerPid [
	"Answer true if an external OS process can receive signals. In most
	cases, if the process identified by anIntegerPid cannot receive signals, it is
	because the process does not exist and anIntegerPid is a stale reference (possibly
	left over from a previous Squeak session). Answer nil if the primitive does
	not exist (possibly because the VM is using an older version of the plugin)."

	<primitive: 'primitiveCanReceiveSignals' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primChdir: pathString [
	"Change current working directory. Does not update the $PWD environment variable."

	<primitive: 'primitiveChdir' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primCreatePipe [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveCreatePipe' module: 'UnixOSProcessPlugin'>
	^ self primMakePipe "try the older deprecated version"
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primCreatePipeWithSessionIdentifier: aByteArray [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveCreatePipeWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ self primMakePipeWithSessionIdentifier: aByteArray "try the older deprecated version"
]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primDisconnectDisplay [
	"Disconnect the X display session. The actual Squeak window on the X server is not
	effected, but this instance of Squeak will not have any further interaction with it."

	"OSProcess thisOSProcess processAccessor primDisconnectDisplay"

	<primitive: 'primitiveDisconnectDisplay' module: 'XDisplayControlPlugin'>
	^ self oldPrimKillDisplay


]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primEnvironmentAt: index [
	"Answer the environment string at index position in the OS process environment list.
	This returns a 'KEY=value' string, which the caller is expected to parse into #KEY
	and 'value' to be stored an environment dictionary."

	<primitive: 'primitiveEnvironmentAt' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primEnvironmentAtSymbol: aSymbol [
	"Answer the value of an environment variable in the external OS process."

	<primitive: 'primitiveEnvironmentAtSymbol' module: 'UnixOSProcessPlugin'>
	^ nil 
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primErrorMessageAt: anInteger [
	"Answer an error message string from the sys_errlist array, indexed by anInteger."

	"OSProcess accessor primErrorMessageAt: 0"
	"OSProcess accessor primErrorMessageAt: 100"
	"OSProcess accessor primErrorMessageAt: 1000"
	"OSProcess accessor primErrorMessageAt: -1"

	<primitive: 'primitiveErrorMessageAt' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primFileProtectionMask: aPathString [
	"Call stat(2) to obtain the file protection mask for a file. Answer an Array of
	four integers representing the protection mask, or answer errno on failure. The
	protection mask is four Integers, each of which may be considered an octal digit
	(0-7), with bit values 4, 2, and 1. The first digit selects the set user ID (4) and set
	group ID (2) and save text image (1) attributes. The second digit selects permissions
	for the user who owns the file: read (4), write (2), and execute (1); the third
	selects permissions for other users in the file's group, with the same values; and
	the fourth for other users not in the file's group, with the same values."

	<primitive: 'primitiveFileProtectionMask' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primFileStat: aPathString [
	"Call stat(2) to obtain the file protection mask for a file. Answer errno on failure,
	or on success answer an array with: UID with: GID with: protectionMask. The	
	protectionMask is an Array of four integers representing the protection mask, or
	answer errno on failure. The protection mask is four Integers, each of which may
	be considered an octal digit (0-7), with bit values 4, 2, and 1. The first digit selects
	the set user ID (4) and set group ID (2) and save text image (1) attributes. The second
	digit selects permissions for the user who owns the file: read (4), write (2), and
	execute (1); the third selects permissions for other users in the file's group, with
	the same values; and the fourth for other users not in the file's group, with the
	same values."

	<primitive: 'primitiveFileStat' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primFlushXDisplay [
	"Call an internal function to synchronize output to the X display."

	"OSProcess thisOSProcess processAccessor primFlushXDisplay"

	<primitive: 'primitiveFlushDisplay' module: 'XDisplayControlPlugin'>
	^ nil


]

{ #category : #deprecated }
UnixOSProcessAccessor >> primForkAndExec: executableFile
	stdIn: inputFileHandle
	stdOut: outputFileHandle
	stdErr: errorFileHandle
	argBuf: argVec
	argOffsets: argOffsets
	envBuf: envVec
	envOffsets: envOffsets
	workingDir: pathString [

	"Parameters are expected to have been properly prepared by the caller, including string
	values which are to be null terminated strings. In other words, all strings should have
	(Character value: 0) as the last element in the string.

	Parameters should be:
		executableFile: a string with the name of a file to execute.
		stdIn: a fileID ByteArray (struct SQFile in C) to be used as standard input.
		stdOut: a fileID ByteArray to be used as standard output.
		stdErr: a fileID ByteArray to be used as standard error.
		argVec: a String arranged to look more or less like a char **, but with the addresses not yet fixed.
		argOffsets: an Array of offsets for fixing up the argVec addresses.
		envVec: a String arranged to look more or less like a char **, but with the addresses not yet fixed.
		envOffsets: an Array of offsets for fixing up the envVec addresses.
		workingDir: a null terminated path name String, or nil.
	The envVec parameter may be nil, in which case envOffsets is ignored. workingDir may be nil. The
	other parameters are required. Parameters with nil value indicate that current values for this process
	should be used."

	<primitive: 'primitiveForkAndExecInDirectory' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #deprecated }
UnixOSProcessAccessor >> primForkAndExec: executableFile
	withArgs: anArrayOfArgumentStrings
	argCount: numberOfArgumentStrings
	withEnv: anArrayOfEnvironmentStrings
	envCount: numberOfEnvironmentStrings
	stdIn: inputFileHandle
	stdOut: outputFileHandle
	stdErr: errorFileHandle [

	"Obsolete as of OSProcess version 1.6 or later (early 2001). This method is retained in
	order to maintain backward compatibility with older versions of UnixOSProcessPlugin."

	"Parameters are expected to have been properly prepared by the caller, including string
	values which are to be null terminated strings. In other words, all strings should have
	(Character value: 0) as the last element in the string.

	Parameters should be:
		executableFile: a string with the name of a file to execute
		args: a possibly empty array of strings
		env: either nil, or an array of 'KEY=value' strings
		stdIn: either nil, or a fileID ByteArray (struct SQFile in C) to be used as standard input
		stdOut: either nil, or fileID ByteArray to be used as standard output
		stdErr: either nil, or a fileID ByteArray to be used as standard error
	Parameters with nil value indicate that current values for this process should be used."

	<primitive: 'primitiveForkAndExec' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'fork and exec' }
UnixOSProcessAccessor >> primForkExec: executableFile
	stdIn: inputFileHandle
	stdOut: outputFileHandle
	stdErr: errorFileHandle
	argBuf: argVec
	argOffsets: argOffsets
	envBuf: envVec
	envOffsets: envOffsets
	workingDir: pathString [

	"Parameters are expected to have been properly prepared by the caller, including string
	values which are to be null terminated strings. In other words, all strings should have
	(Character value: 0) as the last element in the string.

	Parameters should be:
		executableFile: a string with the name of a file to execute.
		stdIn: a fileID ByteArray (struct SQFile in C) to be used as standard input.
		stdOut: a fileID ByteArray to be used as standard output.
		stdErr: a fileID ByteArray to be used as standard error.
		argVec: a String arranged to look more or less like a char **, but with the addresses not yet fixed.
		argOffsets: an Array of offsets for fixing up the argVec addresses.
		envVec: a String arranged to look more or less like a char **, but with the addresses not yet fixed.
		envOffsets: an Array of offsets for fixing up the envVec addresses.
		workingDir: a null terminated path name String, or nil.
	The envVec parameter may be nil, in which case envOffsets is ignored. workingDir may be nil. The
	other parameters are required. Parameters with nil value indicate that current values for this process
	should be used."

	<primitive: 'primitiveForkExec' module: 'UnixOSProcessPlugin'>

	"On failure, try the older deprecated version. First tell the plugin what semaphore to use."
	self primSetSemaIndex: (Smalltalk externalObjects indexOf: OSProcess accessor sigChldSemaphore).
	^ self primForkAndExec: executableFile
		stdIn: inputFileHandle
		stdOut: outputFileHandle
		stdErr: errorFileHandle
		argBuf: argVec
		argOffsets: argOffsets
		envBuf: envVec
		envOffsets: envOffsets
		workingDir: pathString

]

{ #category : #'fork and exec' }
UnixOSProcessAccessor >> primForkSqueak [
	"Clone this Squeak Smalltalk image in a child OSProcess. The child is the same as the
	parent, except for its new X session connection, and the return value of this method,
	which is zero for the child process, and a positive integer equal to the pid of the child
	for the parent process.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	<primitive: 'primitiveForkSqueakWithoutSigHandler' module: 'UnixOSProcessPlugin'>

	"On failure, try the older deprecated version. First tell the plugin what semaphore to use."
	self primSetSemaIndex: (Smalltalk externalObjects indexOf: OSProcess accessor sigChldSemaphore).
	^ self primOldForkSqueak

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primForwardSignal: signalNumber toSemaphore: semaphoreIndex [
	"Set a signal handler in the VM which will signal a Smalltalk semaphore at
	semaphoreIndex whenever an external signal sigNum is received. Answer the
	prior value of the signal handler. If semaphoreIndex is zero, the handler is
	unregistered, and the VM returns to its default behavior for handling that
	signal.

	The Smalltalk semaphore is expected to be kept at the same index location
	indefinitely during the lifetime of a Squeak session. If that is not the case, the
	handler must be unregistered prior to unregistering the Smalltalk semaphore."

	<primitive: 'primitiveForwardSignalToSemaphore' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'fork and exec' }
UnixOSProcessAccessor >> primGetChildExitStatus: childPid [
	"Clean up after the death of a child process, and answer the exit status of the child process."

	<primitive: 'primitiveReapChildProcess' module: 'UnixOSProcessPlugin'>
	^ Array with: childPid with: nil
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetCurrentWorkingDirectory [
	"Call getcwd() to get the current working directory."

	"OSProcess thisOSProcess processAccessor primGetCurrentWorkingDirectory"

	<primitive: 'primitiveGetCurrentWorkingDirectory' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetEGid [
	"Answer the effective group ID for the OS process in which I am currently executing."

	"OSProcess accessor primGetEGid"

	<primitive: 'primitiveGetEGid' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetEUid [
	"Answer the effective user ID for the OS process in which I am currently executing."

	"OSProcess accessor primGetEUid"

	<primitive: 'primitiveGetEUid' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetGid [
	"Answer the group ID for the OS process in which I am currently executing."

	"OSProcess accessor primGetGid"

	<primitive: 'primitiveGetGid' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetPPid [
	"Answer the OS process ID for the parent process of the OS process in which I am
	currently executing."

	<primitive: 'primitiveGetPPid' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetPid [
	"Answer the OS process ID for the OS process in which I am currently executing."

	<primitive: 'primitiveGetPid' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetSession [
	"Answer the unique identifier for this session of Smalltalk running in this OS Process."

	"OSProcess accessor primGetSession"

	<primitive: 'primitiveGetSession' module: 'UnixOSProcessPlugin'>

	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primGetStdErrHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard error for the
	OS process in which I am currently executing."

	<primitive: 'primitiveGetStdErrHandle' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #deprecated }
UnixOSProcessAccessor >> primGetStdErrHandleWithSessionIdentifier: aByteArray [
	"Answer the handle (a SQFile data structure in interp.c) for the standard error for the
	OS process in which I am currently executing."

	<primitive: 'primitiveGetStdErrHandleWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primGetStdInHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard input for
	the OS process in which I am currently executing."

	<primitive: 'primitiveGetStdInHandle' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #deprecated }
UnixOSProcessAccessor >> primGetStdInHandleWithSessionIdentifier: aByteArray [
	"Answer the handle (a SQFile data structure in interp.c) for the standard input for
	the OS process in which I am currently executing."

	<primitive: 'primitiveGetStdInHandleWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primGetStdOutHandle [
	"Answer the handle (a SQFile data structure in interp.c) for the standard output for the
	OS process in which I am currently executing."

	<primitive: 'primitiveGetStdOutHandle' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #deprecated }
UnixOSProcessAccessor >> primGetStdOutHandleWithSessionIdentifier: aByteArray [
	"Answer the handle (a SQFile data structure in interp.c) for the standard output for the
	OS process in which I am currently executing."

	<primitive: 'primitiveGetStdOutHandleWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #pthreads }
UnixOSProcessAccessor >> primGetThreadID [
	"Answer the ID of the pthread that is currently executing (the interpreter thread).
	A thread ID may be a 64 bit value on some platforms, so answer a byte array
	containing the value in machine-dependent byte order."

	"OSProcess accessor primGetThreadID"

	<primitive: 'primitiveGetThreadID' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'external process access' }
UnixOSProcessAccessor >> primGetUid [
	"Answer the user ID for the OS process in which I am currently executing."

	"OSProcess accessor primGetUid"

	<primitive: 'primitiveGetUid' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primGetXDisplayName [
	"Answer a string containing the name for the X display, or nil if the display was opened
	using the $DISPLAY environment variable. This answers the name of the X display as of
	the time it was last opened, which may be different from the current setting of $DISPLAY."

	"OSProcess accessor primGetXDisplayName"

	<primitive: 'primitiveGetDisplayName' module: 'XDisplayControlPlugin'>
	^ self oldPrimGetXDisplayName


]

{ #category : #deprecated }
UnixOSProcessAccessor >> primIsAtEndOfFile: aSqFileStruct [
	"Answer whether the file represented by aSqFileStruct is at end of file, as determined
	by a call to feof(). This is different from StandardFileStream>>primAtEnd: which answers
	true if the file pointer is at the end of the file, but which does not call feof() to
	determine that an end of file condition has occurred. The difference is significant
	if aSqFileStruct represents a pipe or a device file, which may not be positionable
	in the sense of a conventional disk file."

	"WARNING: Do not use this method. The sense of the return value is reversed.
	use #primTestEndOfFileFlag: instead. This method is retained to support use of
	older versions of OSPP."

	<primitive: 'primitiveIsAtEndOfFile' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primIsConnectedToXServer [
	"Answer true if VM is currently connected to an X server."

	"OSProcess accessor primIsConnectedToXServer inspect"
	"| x |
	OSProcess accessor primKillDisplay.
	x _ OSProcess accessor primIsConnectedToXServer.
	OSProcess accessor primOpenXDisplay.
	x inspect"

	<primitive: 'primitiveIsConnectedToDisplay' module: 'XDisplayControlPlugin'>
	^ self oldPrimIsConnectedToXServer


]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primKillDisplay [
	"Disconnect the X display session and destroy the Squeak window on the X display."

	"OSProcess thisOSProcess processAccessor primKillDisplay"

	<primitive: 'primitiveKillDisplay' module: 'XDisplayControlPlugin'>
	^ self oldPrimKillDisplay


]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primLockFileRegion: aSQFileStruct offset: begin length: len exclusive: flag [
	"Pass a struct SQFile on the stack, and request a lock on the specified region.
	If the exclusive flag is true, then request an exclusive (F_WRLCK) lock on the
     file. Otherwise, request a shared (F_RDLCK) lock. Any number of Unix processes
     may  hold  a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock). Answer the result of the call to fcntl()."

	<primitive: 'primitiveLockFileRegion' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #deprecated }
UnixOSProcessAccessor >> primMakePipe [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveMakePipe' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #deprecated }
UnixOSProcessAccessor >> primMakePipeWithSessionIdentifier: aByteArray [
	"Create a pipe, and answer an array of two file handles (SQFile data structures in interp.c)
	for the pipe reader and writer."

	<primitive: 'primitiveMakePipeWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'fork and exec' }
UnixOSProcessAccessor >> primNice: inc [
	"Change the scheduling priority of this OS process by the given nice increment."

	<primitive: 'primitiveNice' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primOSProcessPluginModuleName [
	"Answer a string containing the module name string for the OSPP plugin."

	"OSProcess accessor primOSProcessPluginModuleName"

	<primitive: 'primitiveModuleName' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primOSProcessPluginModuleVersionString [
	"Answer a string containing the version string for the OSPP plugin."

	"OSProcess accessor primOSProcessPluginModuleVersionString"

	<primitive: 'primitiveVersionString' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #deprecated }
UnixOSProcessAccessor >> primOldForkSqueak [
	"Clone this Squeak Smalltalk image in a child OSProcess. The child is the same as the
	parent, except for its new X session connection, and the return value of this method,
	which is zero for the child process, and a positive integer equal to the pid of the child
	for the parent process.

	The child should not depend on using existing connections to external resources. For
	example, the child may lose its connections to stdin, stdout, and stderr after its parent
	exits."

	<primitive: 'primitiveForkSqueak' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primOpenXDisplay [
	"Call an internal function which will open the X display session."

	"OSProcess thisOSProcess processAccessor primKillDisplay.
	(Delay forSeconds: 5) wait.
	OSProcess thisOSProcess processAccessor primOpenXDisplay"

	<primitive: 'primitiveOpenDisplay' module: 'XDisplayControlPlugin'>
	^ self oldPrimOpenXDisplay


]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primPutEnv: aString [
	"Add or update an environment variable in the external OS process using a 'KEY=value'
	string."

	<primitive: 'primitivePutEnv' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primRealpath: pathString [
	"Resolve pathString into a real path if possible, or answer nil."

	<primitive: 'primitiveRealpath' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primSQFileFlush: aSQFileStruct [
	"Pass a struct SQFile on the stack, flush the external file stream."

	<primitive: 'primitiveSQFileFlush' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #deprecated }
UnixOSProcessAccessor >> primSQFileFlush: aSQFileStruct withSessionIdentifier: aByteArray [
	"Pass a struct SQFile on the stack, flush the external file stream."

	<primitive: 'primitiveSQFileFlushWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primSQFileSetBlocking: aSQFileStruct [
	"Pass a struct SQFile on the stack, and call fcntl() to set the file non-blocking."

	<primitive: 'primitiveSQFileSetBlocking' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #deprecated }
UnixOSProcessAccessor >> primSQFileSetBlocking: aSQFileStruct withSessionIdentifier: aByteArray [
	"Pass a struct SQFile on the stack, and call fcntl() to set the file non-blocking."

	<primitive: 'primitiveSQFileSetBlockingWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primSQFileSetNonBlocking: aSQFileStruct [
	"Pass a struct SQFile on the stack, and call fcntl() to set the file non-blocking."

	<primitive: 'primitiveSQFileSetNonBlocking' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #deprecated }
UnixOSProcessAccessor >> primSQFileSetNonBlocking: aSQFileStruct withSessionIdentifier: aByteArray [
	"Pass a struct SQFile on the stack, and call fcntl() to set the file non-blocking."

	<primitive: 'primitiveSQFileSetNonBlockingWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primSQFileSetUnbuffered: aSQFileStruct [
	"Pass a struct SQFile on the stack, set the file non-blocking."

	<primitive: 'primitiveSQFileSetUnbuffered' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #deprecated }
UnixOSProcessAccessor >> primSQFileSetUnbuffered: aSQFileStruct withSessionIdentifier: aByteArray [
	"Pass a struct SQFile on the stack, set the file non-blocking."

	<primitive: 'primitiveSQFileSetUnbufferedWithSessionIdentifier' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSemaIndexFor: sigNum [
	"Answer the registration index of the semaphore currently associated with the
	signal handler for sigNum."

	<primitive: 'primitiveSemaIndexFor' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigabrtTo: anIntegerPid [
	"Send SIGABRT (abort) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigabrtTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigalrmTo: anIntegerPid [
	"Send SIGALRM (alarm) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigalrmTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigchldTo: anIntegerPid [
	"Send SIGCHLD (child status has changed, usually death of child) to the OS process
	identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigchldTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigcontTo: anIntegerPid [
	"Send SIGCONT (continue) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigcontTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSighupTo: anIntegerPid [
	"Send SIGHUP (hangup) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSighupTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigintTo: anIntegerPid [
	"Send SIGINT (interrupt) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigintTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigkillTo: anIntegerPid [
	"Send SIGKILL (kill, unblockable) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigkillTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigpipeTo: anIntegerPid [
	"Send SIGPIPE (broken pipe) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigpipeTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigquitTo: anIntegerPid [
	"Send SIGQUIT (quit) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigquitTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigstopTo: anIntegerPid [
	"Send SIGSTOP (stop, unblockable) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigstopTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigtermTo: anIntegerPid [
	"Send SIGTERM (termination) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigtermTo' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigusr1To: anIntegerPid [
	"Send SIGUSR1 (User-defined signal 1) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigusr1To' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #'OS signal sending' }
UnixOSProcessAccessor >> primSendSigusr2To: anIntegerPid [
	"Send SIGUSR2 (User-defined signal 2) to the OS process identified by anIntegerPid.
	Answer 0 on success, -1 on failure, and nil if the pluggable primitive is not present."

	<primitive: 'primitiveSendSigusr2To' module: 'UnixOSProcessPlugin'>
	^ nil


]

{ #category : #deprecated }
UnixOSProcessAccessor >> primSetSemaIndex: anInteger [
	"Tell the virtual machine what semaphore to use when handling a death of child signal."

	<primitive: 'primitiveSetSemaIndex' module: 'UnixOSProcessPlugin'>
	^ anInteger
]

{ #category : #'display handling' }
UnixOSProcessAccessor >> primSetXDisplayName: aStringOrNil [
	"Set the name for the X display for use in the next call to primitiveOpenXDisplay.
	aStringOrNil must be either a String (such as 'myhost:0') or nil, indicating that
	the current value of $DISPLAY should be used."

	"OSProcess accessor primSetXDisplayName: ':0.0' "
	"OSProcess accessor primSetXDisplayName: nil "

	<primitive: 'primitiveSetDisplayName' module: 'XDisplayControlPlugin'>
	^ self oldPrimSetXDisplayName: aStringOrNil


]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigChldNumber [
	"Integer value corresponding to SIGCHLD"

	<primitive: 'primitiveSigChldNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigHupNumber [
	"Integer value corresponding to SIGHUP"

	<primitive: 'primitiveSigHupNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigIntNumber [
	"Integer value corresponding to SIGINT"

	"OSProcess accessor primSigIntNumber"

	<primitive: 'primitiveSigIntNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigKillNumber [
	"Integer value corresponding to SIGKILL"

	"OSProcess accessor primSigKillNumber"

	<primitive: 'primitiveSigKillNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigPipeNumber [
	"Integer value corresponding to SIGPIPE"

	<primitive: 'primitiveSigPipeNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigQuitNumber [
	"Integer value corresponding to SIGQUIT"

	<primitive: 'primitiveSigQuitNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigTermNumber [
	"Integer value corresponding to SIGTERM"

	<primitive: 'primitiveSigTermNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigUsr1Number [
	"Integer value corresponding to SIGUSR1"

	<primitive: 'primitiveSigUsr1Number' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - signal forwarding' }
UnixOSProcessAccessor >> primSigUsr2Number [
	"Integer value corresponding to SIGUSR2"

	<primitive: 'primitiveSigUsr2Number' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primSizeOfInt [
	"Size of an integer for this C compiler on this machine."

	<primitive: 'primitiveSizeOfInt' module: 'UnixOSProcessPlugin'>
	^ self primitiveFailed

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primSizeOfPointer [
	"Size of a void pointer for this C compiler on this machine."

	<primitive: 'primitiveSizeOfPointer' module: 'UnixOSProcessPlugin'>
	^ self primitiveFailed

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primTestEndOfFileFlag: aSqFileStruct [
	"Answer whether the file represented by aSqFileStruct is at end of file, as determined
	by a call to feof(). This is different from StandardFileStream>>primAtEnd: which answers
	true if the file pointer is at the end of the file, but which does not call feof() to
	determine that an end of file condition has occurred. The difference is significant
	if aSqFileStruct represents a pipe or a device file, which may not be positionable
	in the sense of a conventional disk file."

	<primitive: 'primitiveTestEndOfFileFlag' module: 'UnixOSProcessPlugin'>
	^ ((self primIsAtEndOfFile: aSqFileStruct) ifNil: [^nil]) not

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primTestLockableFileRegion: aSQFileStruct offset: begin length: len exclusive: flag [
	"Pass a struct SQFile on the stack, and check for ability to lock the specified region.
	If the exclusive flag is true, then specify an exclusive (F_WRLCK) lock on the
     file. Otherwise, specify a shared (F_RDLCK) lock. Any number of Unix processes
     may hold  a read lock (shared lock) on a file region, but only one process may
     hold a write lock (exclusive lock).

	If length is zero, then the request is for the entire file to be locked, including
	region extents that have not yet been allocated for the file.

	If the fcntl() call fails, answer -1 (the result of the failed call). Otherwise,
	answer an array with the following six fields:
		lockable (true or false)
		l_pid (pid of the process preventing this lock request, or nil)
		l_type (request type F_WRLCK or F_RDLOCK of the process preventing this lock request)
		l_whence (the SEEK_SET, SEEK_CUR, or SEEK_END value of the lock preventing this lock request).
		l_start (offset of the region lock preventing this lock request)
		l_len (length of the region lock preventing this lock request)"

	<primitive: 'primitiveTestLockableFileRegion' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primUnixFileNumber: aSQFileStruct [
	"Pass a struct SQFile on the stack, and answer the corresponding Unix file number."

	<primitive: 'primitiveUnixFileNumber' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primUnlockFileRegion: aSQFileStruct offset: begin length: len [
	"Pass a struct SQFile on tthe stack, and unlock the specified region.
	Answer the result of the call to fcntl(). If the region is in the file lock cache,
	remove it, but otherwise ignore the cache. The cache supports Win32 semantics
	within a single Squeak image, but not across separate images, therefore the
	unlock should be attempted regardless of whether this image thinks that the
	region has previously been locked. Answer the result of the call to fcntl()."

	<primitive: 'primitiveUnlockFileRegion' module: 'UnixOSProcessPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primUnsetEnv: aKeyString [
	"Remove an environment variable from the external OS process environment."

	<primitive: 'primitiveUnsetEnv' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primXDisplayControlPluginModuleName [
	"Answer a string containing the module name string for the display control plugin."

	"OSProcess accessor primXDisplayControlPluginModuleName"

	<primitive: 'primitiveModuleName' module: 'XDisplayControlPlugin'>
	^ nil

]

{ #category : #'private - primitive access' }
UnixOSProcessAccessor >> primXDisplayControlPluginModuleVersionString [
	"Answer a string containing the version string for the display control plugin."

	"OSProcess accessor primXDisplayControlPluginModuleVersionString"

	<primitive: 'primitiveVersionString' module: 'XDisplayControlPlugin'>
	^ nil

]

{ #category : #printing }
UnixOSProcessAccessor >> printOn: aStream [
	"In English, say 'a Unix' rather than 'an Unix'. Therefore do not use super printOn, which
	treats $U as a vowel."

	aStream
		nextPutAll: 'a ';
		nextPutAll: self class name;
		nextPutAll: ' on pid ';
		nextPutAll: self primGetPid printString

]

{ #category : #'external process access' }
UnixOSProcessAccessor >> putPath: aString [
	"Convenience method. Set the environment PATH variable to aString."

	| pathString |
	pathString _ 'PATH=', aString, ((Character value: 0) asString). 
	^ self environmentPut: pathString





]

{ #category : #'external process access' }
UnixOSProcessAccessor >> realpath: pathString [
	"Get the real path for pathString from the external OS process."

	"OSProcess accessor realpath: '/tmp'"
	"OSProcess accessor realpath: FileDirectory default pathName"
	"OSProcess accessor realpath: '/bogus/path/name'"

	^ self primRealpath: pathString

]

{ #category : #'file lock registry' }
UnixOSProcessAccessor >> register: fileRegionLock [
	"If an object equal to fileRegionLock exists in the registry, answer it. Otherwise, add
	fileRegionLock to the registry and answer fileRegionLock. Caching is enabled when
	EmulateWin32FileLocking is true."

	^ self emulateWin32FileLocking
		ifTrue: [super register: fileRegionLock]
		ifFalse: [fileRegionLock]

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigChld [
	"Unset a SIGCHLD signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigChld"

	^ self restoreSignal: self primSigChldNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigHup [
	"Unset a SIGHUP signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigHup"

	^ self restoreSignal: self primSigHupNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigInt [
	"Unset a SIGINT signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigInt"

	^ self restoreSignal: self primSigIntNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigKill [
	"Unset a SIGKILL signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigKill"

	self notify: 'SIGKILL and SIGSTOP signals cannot be caught, see man signal(2)'.
	^ self restoreSignal: self primSigIntNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigPipe [
	"Unset a SIGPIPE signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigPipe"

	^ self restoreSignal: self primSigPipeNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigQuit [
	"Unset a SIGQUIT signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigQuit"

	^ self restoreSignal: self primSigQuitNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigTerm [
	"Unset a SIGTERM signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigTerm"

	^ self restoreSignal: self primSigTermNumber

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigUsr1 [
	"Unset a SIGUSR1 signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigUsr1"

	^ self restoreSignal: self primSigUsr1Number

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSigUsr2 [
	"Unset a SIGUSR2 signal handler and unregister the Smalltalk semaphore.
	Answer the unregistered Semaphore, or nil if unable to restore the signal
	(possibly because no handler had been set)."

	"OSProcess accessor restoreSigUsr2"

	^ self restoreSignal: self primSigUsr2Number

]

{ #category : #'signal forwarding' }
UnixOSProcessAccessor >> restoreSignal: signalNumber [ 
	"Unset a signal handler and unregister the Smalltalk semaphore. Answer
	the unregistered Semaphore, or nil if unable to restore the signal (possibly
	because no handler had been set)."

	"OSProcess accessor restoreSignal: OSProcess accessor primSigIntNumber"

	| semaphoreIndex sema |
	semaphoreIndex _ self primSemaIndexFor: signalNumber.
	semaphoreIndex ifNotNil:
		[sema _ Smalltalk externalObjects at: semaphoreIndex ifAbsent: [].
		sema ifNotNil:
			[self primForwardSignal: signalNumber toSemaphore: nil.
			Smalltalk unregisterExternalObject: sema]].
	^ sema

]

{ #category : #'file control' }
UnixOSProcessAccessor >> setBlocking: anIOHandle [
	"Convert anIOHandle to an SQFile data structure and call primitive to set for blocking I/O."

	^ self canObtainSessionIdentifierFromPlugin
		ifTrue: [self primSQFileSetBlocking: (self handleFromAccessor: anIOHandle)]
		ifFalse: [self primSQFileSetBlocking: (self handleFromAccessor: anIOHandle) withSessionIdentifier: self sessionIdentifier]

]

{ #category : #'file control' }
UnixOSProcessAccessor >> setNonBlocking: anIOHandle [
	"Convert anIOHandle to an SQFile data structure and call primitive to set it non-blocking."

	^ self canObtainSessionIdentifierFromPlugin
		ifTrue: [self primSQFileSetNonBlocking: (self handleFromAccessor: anIOHandle)]
		ifFalse: [self primSQFileSetNonBlocking: (self handleFromAccessor: anIOHandle) withSessionIdentifier: self sessionIdentifier]

]

{ #category : #'file control' }
UnixOSProcessAccessor >> setUnbuffered: anIOHandle [
	"Convert anIOHandle to an SQFile data structure and call primitive to set unbuffered I/O."

	^ self canObtainSessionIdentifierFromPlugin
		ifTrue: [self primSQFileSetUnbuffered: (self handleFromAccessor: anIOHandle)]
		ifFalse: [self primSQFileSetUnbuffered: (self handleFromAccessor: anIOHandle) withSessionIdentifier: self sessionIdentifier]

]

{ #category : #accessing }
UnixOSProcessAccessor >> sigChldSemaphore [
	"Answer the value of sigChldSemaphore"

	^ sigChldSemaphore ifNil: [sigChldSemaphore _ self forwardSigChld].

]

{ #category : #accessing }
UnixOSProcessAccessor >> sigChldSemaphore: anObject [
	"Set the value of sigChldSemaphore"

	sigChldSemaphore _ anObject
]

{ #category : #testing }
UnixOSProcessAccessor >> sizeOfInt [
	"Size of an integer on this machine with this C compiler."

	^ self primSizeOfInt
]

{ #category : #testing }
UnixOSProcessAccessor >> sizeOfPointer [
	"Size of a void pointer on this machine with this C compiler."

	^ self primSizeOfPointer
]

{ #category : #'file control' }
UnixOSProcessAccessor >> unixFileNumber: anIOHandle [
	"Answer the integer Unix file number corresponding to anIOHandle."

	^ anIOHandle ifNotNil: [self primUnixFileNumber: (self handleFromAccessor: anIOHandle)]

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockAllForFile: aFileStream [
	"Unlock and uncache all locks associated with aFileStream.  This could be called
	before closing a stream, for example."

	(self registeredLocksForFile: aFileStream) do: [:ea | self unlockFileRegion: ea]

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFile: aFileStream [
	"Unlock the file represented by aFileStream.  Answer a descriptor for the unlocked
	file region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self unlockFile: aFileStream exclusive: true

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFile: aFileStream exclusive: flag [
	"Unlock the file represented by aFileStream.  Answer a descriptor for the unlocked
	file region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	| fileLock |
	aFileStream ifNil: [^ nil].
	fileLock _ OSFileLock onFile: aFileStream exclusive: flag.
	^ self unlockFileRegion: fileLock

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFile: aFileStream exclusive: flag ifFail: failBlock [
	"Unlock the file represented by aFileStream.  Answer a descriptor for the unlocked
	file region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	| fileLock |
	aFileStream ifNil: [^ failBlock value].
	fileLock _ OSFileLock onFile: aFileStream exclusive: flag.
	^ self unlockFileRegion: fileLock ifFail: failBlock


]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFile: aFileStream from: start to: end [
	"Pass a struct SQFile on the stack, and unlock the specified region.
	Answer the result of the call to fcntl(). If the region is in the file lock cache,
	remove it, but otherwise ignore the cache. The cache supports Win32 semantics
	within a single Squeak image, but not across separate images, therefore the
	unlock should be attempted regardless of whether this image thinks that the
	region has previously been locked. Answer a descriptor for the unlocked file
	region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self unlockFile: aFileStream from: start to: end exclusive: true

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFile: aFileStream from: start to: end exclusive: flag [
	"Pass a struct SQFile on the stack, and unlock the specified region.
	Answer the result of the call to fcntl(). If the region is in the file lock cache,
	remove it, but otherwise ignore the cache. The cache supports Win32 semantics
	within a single Squeak image, but not across separate images, therefore the
	unlock should be attempted regardless of whether this image thinks that the
	region has previously been locked. Answer a descriptor for the unlocked file
	region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	| fileRegion |
	aFileStream ifNil: [^ nil].
	fileRegion _ OSFileRegionLock onFile: aFileStream from: start to: end exclusive: flag.
	^ self unlockFileRegion: fileRegion

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFile: aFileStream ifFail: failBlock [
	"Unlock the file represented by aFileStream.  Answer a descriptor for the unlocked
	file region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self unlockFile: aFileStream exclusive: true ifFail: failBlock

]

{ #category : #deprecated }
UnixOSProcessAccessor >> unlockFile: aFileStream region: anInterval [
	"Pass a struct SQFile on the stack, and unlock the specified region.
	Answer the result of the call to fcntl(). If the region is in the file lock cache,
	remove it, but otherwise ignore the cache. The cache supports Win32 semantics
	within a single Squeak image, but not across separate images, therefore the
	unlock should be attempted regardless of whether this image thinks that the
	region has previously been locked. Answer a descriptor for the unlocked file
	region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	| fileRegion |
	aFileStream ifNil: [^ nil].
	fileRegion _ OSFileRegionLock onFile: aFileStream interval: anInterval exclusive: true.
	^ self unlockFileRegion: fileRegion

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFileRegion: aFileLock [
	"Pass a struct SQFile on the stack, and unlock the specified region.
	Answer the result of the call to fcntl(). If the region is in the file lock cache,
	remove it, but otherwise ignore the cache. The cache supports Win32 semantics
	within a single Squeak image, but not across separate images, therefore the
	unlock should be attempted regardless of whether this image thinks that the
	region has previously been locked. Answer a descriptor for the unlocked file
	region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	^ self unlockFileRegion: aFileLock ifFail: [nil]

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFileRegion: fileStream from: start to: end exclusive: writeLockFlag ifFail: failBlock [

	| lock |
	lock _ OSFileRegionLock onFile: fileStream from: start to: end exclusive: writeLockFlag.
	^ self unlockFileRegion: lock ifFail: [failBlock value]
]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFileRegion: fileStream from: start to: end ifFail: failBlock [

	^ self unlockFileRegion: fileStream from: start to: end exclusive: true ifFail: failBlock

]

{ #category : #'file locking' }
UnixOSProcessAccessor >> unlockFileRegion: aFileLock ifFail: failBlock [
	"Pass a struct SQFile on the stack, and unlock the specified region.
	Answer the result of the call to fcntl(). If the region is in the file lock cache,
	remove it, but otherwise ignore the cache. The cache supports Win32 semantics
	within a single Squeak image, but not across separate images, therefore the
	unlock should be attempted regardless of whether this image thinks that the
	region has previously been locked. Answer a descriptor for the unlocked file
	region, an Array of file handle and region interval; or answer nil on error
	or if the region did not appear in the cache.

	Warning: The registry permits compatibility with Win32 file locking semantics,
	but only within a single Squeak image. Multiple cooperating images must not
	rely on the overlap checking, because the registry is local to this image and
	cannot be shared across images in different OS process contexts."

	aFileLock ifNil: [^ failBlock value].
	"Check region lock overlap for Win32 compatibility"
	self emulateWin32FileLocking
		ifTrue: [ | unregisteredLock |
				(unregisteredLock _ self unregister: aFileLock)
					ifNil: [^ failBlock value]
					ifNotNil: [^ unregisteredLock unlockIfFail: failBlock; yourself]]
		ifFalse: [^ aFileLock unlockIfFail: failBlock; yourself]
]

{ #category : #'file lock registry' }
UnixOSProcessAccessor >> unregister: fileRegionLock [
	"If an object equal to fileRegionLock exists in the registry, remove it and
	answer the object. Otherwise answer nil. Caching is enabled when
	EmulateWin32FileLocking is true."

	^ self emulateWin32FileLocking
		ifTrue: [super unregister: fileRegionLock]
		ifFalse: [nil]

]

{ #category : #'plugin identification' }
UnixOSProcessAccessor >> xdcpModuleName [
	"Answer a string containing the module name string for the display control plugin."

	"OSProcess accessor xdcpModuleName"

	^ self primXDisplayControlPluginModuleName

]

{ #category : #'plugin identification' }
UnixOSProcessAccessor >> xdcpVersionString [
	"Answer a string containing the version string for the display control plugin."

	"OSProcess accessor xdcpVersionString"

	^ self primXDisplayControlPluginModuleVersionString

]
