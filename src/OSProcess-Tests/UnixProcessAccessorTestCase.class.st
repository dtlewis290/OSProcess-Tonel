"
Unit tests for the UnixProcessAccessor.
"
Class {
	#name : #UnixProcessAccessorTestCase,
	#superclass : #TestCase,
	#instVars : [
		'accessor'
	],
	#category : #'OSProcess-Tests'
}

{ #category : #'testing - C string arrays' }
UnixProcessAccessorTestCase >> primFixPointersInArrayOfStrings: cStringArray withOffsets: offsetArray count: count [
	"This primitive call exists only for purposes of testing the
	fixPointersInArrayOfStrings:withOffsets:count: method. I believe it to be
	reasonably machine and compiler independent, but have no way of verifying
	this on a variety of machines, so I'll leave this test method here in case
	someone runs into problems on other hardware or compilers. -dtl"

	"| a |
	a := OSProcess thisOSProcess envAsFlatArrayAndOffsets: UnixProcess env.
	UnixProcessAccessorTestCase new
		primFixPointersInArrayOfStrings: (a at: 1)
		withOffsets: (a at: 2)
		count: (a at: 2) size"

	<primitive: 'primitiveFixPointersInArrayOfStrings' module: 'UnixOSProcessPlugin'>
	^ nil
]

{ #category : #running }
UnixProcessAccessorTestCase >> runAll [

	"UnixProcessAccessorTestCase new runAll"

	| result suite |
	suite := TestSuite new.
	suite addTest: (UnixProcessAccessorTestCase selector: #testSessionIdentifier).
	suite addTest: (UnixProcessAccessorTestCase selector: #testCanAccessSystem).
	suite addTest: (UnixProcessAccessorTestCase selector: #testMakePipeHandles).
	suite addTest: (UnixProcessAccessorTestCase selector: #testUnixFileNumber).
	suite addTest: (UnixProcessAccessorTestCase selector: #testFileProtectionMask).
	suite addTest: (UnixProcessAccessorTestCase selector: #testFileStat).
	suite addTest: (UnixProcessAccessorTestCase selector: #testIsExecutable).
	suite addTest: (UnixProcessAccessorTestCase selector: #testIsExecutableForUserInGroup).
	suite addTest: (UnixProcessAccessorTestCase selector: #testIsReadable).
	suite addTest: (UnixProcessAccessorTestCase selector: #testIsReadableForUserInGroup).
	suite addTest: (UnixProcessAccessorTestCase selector: #testIsWritable).
	suite addTest: (UnixProcessAccessorTestCase selector: #testIsWritableForUserInGroup).

	suite addTest: (UnixProcessAccessorTestCase selector: #runExternalProcessAccess).
	suite addTest: (UnixProcessAccessorTestCase selector: #runForkAndExec).

	result := suite run.
	self should: [result defects size == 0].
	^ result

]

{ #category : #running }
UnixProcessAccessorTestCase >> runExternalProcessAccess [

	"UnixProcessAccessorTestCase new runExternalProcessAccess"

	| result suite |
	suite := TestSuite new.
	suite addTest: (UnixProcessAccessorTestCase selector: #testCanAccessSystem).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetCurrentWorkingDirectory).
	suite addTest: (UnixProcessAccessorTestCase selector: #testChDir).
	suite addTest: (UnixProcessAccessorTestCase selector: #testEnvironmentAt).
	suite addTest: (UnixProcessAccessorTestCase selector: #testEnvironmentAtPut1).
	suite addTest: (UnixProcessAccessorTestCase selector: #testEnvironmentAtPut2).
	suite addTest: (UnixProcessAccessorTestCase selector: #testEnvironmentAtPut).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimUnsetEnv).
	suite addTest: (UnixProcessAccessorTestCase selector: #testGetStdInHandle).
	suite addTest: (UnixProcessAccessorTestCase selector: #testGetStdOutHandle).
	suite addTest: (UnixProcessAccessorTestCase selector: #testGetStdErrHandle).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimArgumentAt).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimErrorMessageAt).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetPid).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetGid).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetEGid).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetPid).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetPPid).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetUid).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetSession).
	suite addTest: (UnixProcessAccessorTestCase selector: #testRealpath).

	result := suite run.
	self should: [result defects size == 0].
	^ result

]

{ #category : #running }
UnixProcessAccessorTestCase >> runForkAndExec [
	"Most of this must be tested from class UnixProcess"

	"UnixProcessAccessorTestCase new runForkAndExec"

	| result suite |
	suite := TestSuite new.
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimGetChildExitStatus).
	suite addTest: (UnixProcessAccessorTestCase selector: #testPrimForkAndExec).
	result := suite run.
	self should: [result defects size == 0].
	^ result

]

{ #category : #running }
UnixProcessAccessorTestCase >> setUp [

	accessor := ThisOSProcess accessor
]

{ #category : #'testing - C string arrays' }
UnixProcessAccessorTestCase >> testArgsAsFlatArrayAndOffsets [
	"Test conversion of an array of strings into the form used to create a C **char
	in UnixOSProcessPlugin."

	"(UnixProcessAccessorTestCase selector: #testArgsAsFlatArrayAndOffsets) debug"

	| a pointerSize lengthOfCStrings totalLength stringsAndOffsets rs s arrayWithMachineDependentPointers |
	pointerSize := OSProcess accessor sizeOfPointer.
	a := { 'one' . 'two' . 'three' } collect: [ :e | e , (Character value: 0) asString ].
	stringsAndOffsets := OSProcess thisOSProcess argsAsFlatArrayAndOffsets: a.
	self assert: stringsAndOffsets size == 2.
	self assert: stringsAndOffsets second size == 3.
	lengthOfCStrings := (a collect: [:e | e size]) sum.
	totalLength := 4 * pointerSize + lengthOfCStrings.
	self assert: stringsAndOffsets first size == totalLength.
	stringsAndOffsets second do: [:offset |
		(stringsAndOffsets first at: offset) == (Character value: 0)].

	rs := ReadStream on: stringsAndOffsets first.
	rs next: 4 * pointerSize.
	s :=  rs next: 3.
	rs next.
	self assert: s = 'one'.
	s :=  rs next: 3.
	rs next.
	self assert: s = 'two'.
	s :=  rs next: 5.
	rs next.
	self assert: s = 'three'.

	rs := ReadStream on: stringsAndOffsets first.
	rs next: (stringsAndOffsets second at: 1).
	s :=  rs next: 3.
	self assert: s = 'one'.
	rs := ReadStream on: stringsAndOffsets first.
	rs next: (stringsAndOffsets second at: 2).
	s :=  rs next: 3.
	self assert: s = 'two'.
	rs := ReadStream on: stringsAndOffsets first.
	rs next: (stringsAndOffsets second at: 3).
	s :=  rs next: 5.
	self assert: s = 'three'.

	arrayWithMachineDependentPointers := self
		primFixPointersInArrayOfStrings: stringsAndOffsets first
		withOffsets: stringsAndOffsets second
		count: stringsAndOffsets second size.
	self assert: arrayWithMachineDependentPointers size == stringsAndOffsets first size.
	rs := ReadStream on: arrayWithMachineDependentPointers.
	s := rs next: pointerSize.
	self assert: s ~= (String new: pointerSize). "a C pointer"
	s := rs next: pointerSize.
	self assert: s ~= (String new: pointerSize). "a C pointer"
	s := rs next: pointerSize.
	self assert: s ~= (String new: pointerSize). "a C pointer"
	s := rs next: pointerSize.
	self assert: s = (String new: pointerSize). "a NULL pointer"
	self assert: rs upToEnd = (stringsAndOffsets first allButFirst: pointerSize * 4)

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testCanAccessSystem [

	"(UnixProcessAccessorTestCase selector: #testCanAccessSystem) run"

	self assert: accessor canAccessSystem
]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testChDir [

	"(UnixProcessAccessorTestCase selector: #testChDir) run"

	| cwd new |
	cwd := accessor primGetCurrentWorkingDirectory.
	new := '/bin'. "nb Do not use /tmp because OS X implements it as a sym link to private/tmp"
	accessor chDir: new.
	self should: [new = accessor primGetCurrentWorkingDirectory].
	accessor chDir: cwd.
	self should: [cwd = accessor primGetCurrentWorkingDirectory].

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testDupTo [
	"Perform a dup2() call to assign IO to a new file stream"

	"(UnixProcessAccessorTestCase selector: #testDupTo) run"

	| f1 f2 fd1 fd2 result contents1 contents2 |
	OSProcess deleteFileNamed: '/tmp/delete-1.me'.	
	OSProcess deleteFileNamed: '/tmp/delete-2.me'.	
	f1 := OSProcess newFileNamed: '/tmp/delete-1.me'.
	f2 := OSProcess newFileNamed: '/tmp/delete-2.me'.
	fd1 := OSProcess accessor primUnixFileNumber: f1 fileID.
	fd2 := OSProcess accessor primUnixFileNumber: f2 fileID.
	result := OSProcess accessor primDup: fd1 to: fd2.
	"f1 and f2 now both refer to the same IO stream"
	self assert: result = fd2.
	f2 nextPutAll: 'write something to the original f2 file stream that will appear in duped f1 instead'; flush.
	f1 reset.
	contents1 := f1 upToEnd.
	self deny: contents1 isEmpty.
	self assert: ('write something*' match: contents1).
	f2 reset.
	contents2 := f2 upToEnd.
	self deny: contents2 isEmpty.
	self assert: ('write something*' match: contents2).
	f1 close.
	f2 close.
	"check the contents of the actual files"
	contents1 := (OSProcess fileNamed: '/tmp/delete-1.me') contentsOfEntireFile.
	self assert: ('write something*' match: contents1).
	contents2 := (OSProcess fileNamed: '/tmp/delete-2.me') contentsOfEntireFile.
	self assert: contents2 isEmpty.
	OSProcess deleteFileNamed: '/tmp/delete-1.me'.	
	OSProcess deleteFileNamed: '/tmp/delete-2.me'.	

]

{ #category : #'testing - C string arrays' }
UnixProcessAccessorTestCase >> testEnvAsFlatArrayAndOffsets [
	"Test conversion of a dictionary of key-value environment variables into the
	form used to create a C **char in UnixOSProcessPlugin."

	"(UnixProcessAccessorTestCase selector: #testEnvAsFlatArrayAndOffsets) debug"

	| pointerSize lengthOfCStrings totalLength stringsAndOffsets rs s arrayWithMachineDependentPointers d |
	pointerSize := OSProcess accessor sizeOfPointer.
	d := Dictionary new.
	d at: #ONE put: 'one'.
	d at: #TWO put: 'two'.
	d at: #THREE put: 'three'.
	stringsAndOffsets := OSProcess thisOSProcess envAsFlatArrayAndOffsets: d.
	self assert: stringsAndOffsets size == 2.
	self assert: stringsAndOffsets second size == 3.

	lengthOfCStrings := d keys
		inject: 0
		into: [:sum :e | sum + e size + '=' size + (d at: e) size + (String new: 1) size].

	totalLength := 4 * pointerSize + lengthOfCStrings.
	self assert: stringsAndOffsets first size == totalLength.
	stringsAndOffsets second do: [:offset |
		(stringsAndOffsets first at: offset) == (Character value: 0)].

	arrayWithMachineDependentPointers := self
		primFixPointersInArrayOfStrings: stringsAndOffsets first
		withOffsets: stringsAndOffsets second
		count: stringsAndOffsets second size.
	self assert: arrayWithMachineDependentPointers size == stringsAndOffsets first size.
	rs := ReadStream on: arrayWithMachineDependentPointers.
	s := rs next: pointerSize.
	self assert: s ~= (String new: pointerSize). "a C pointer"
	s := rs next: pointerSize.
	self assert: s ~= (String new: pointerSize). "a C pointer"
	s := rs next: pointerSize.
	self assert: s ~= (String new: pointerSize). "a C pointer"
	s := rs next: pointerSize.
	self assert: s = (String new: pointerSize). "a NULL pointer"
	self assert: rs upToEnd = (stringsAndOffsets first allButFirst: pointerSize * 4)

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testEnvironmentAt [

	"(UnixProcessAccessorTestCase selector: #testEnvironmentAt) run"

	| path |
	path := accessor environmentAt: 'PATH'.
	self should: [path notNil and: [path isEmpty not]]
]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testEnvironmentAtPut [

	"(UnixProcessAccessorTestCase selector: #testEnvironmentAtPut) run"

	| oldPath newPath resetPath s |
	oldPath := accessor environmentAt: 'PATH'.
	newPath := 'this is a test string'.
	accessor environmentAt: 'PATH' put: newPath.
	resetPath := accessor environmentAt: 'PATH'.
	self should: [newPath = resetPath].
	accessor environmentAt: 'PATH' put: oldPath.
	resetPath := accessor environmentAt: 'PATH'.
	self should: [oldPath = resetPath].
	s := WriteStream on: String new.
	10000 timesRepeat: [s nextPutAll: 'Do something to provoke garbage collection'].
	resetPath := accessor environmentAt: 'PATH'.
	self should: [oldPath = resetPath].



]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testEnvironmentAtPut1 [

	"(UnixProcessAccessorTestCase selector: #testEnvironmentAtPut1) run"

	| oldVal newVal resetVal |
	oldVal := accessor environmentAt: 'AAAA'.
	newVal := 'this is a test string'.
	accessor environmentAt: 'AAAA' put: newVal.
	resetVal := accessor environmentAt: 'AAAA'.
	self should: [resetVal notNil and: [resetVal isEmpty not]].
	self should: [newVal = resetVal].
	accessor environmentAt: 'AAAA' put: oldVal.
	self should: [oldVal = (accessor environmentAt: 'AAAA')]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testEnvironmentAtPut2 [
	"This looks for a bug in which the enviroment is successfully, but later gets
	invalidated by memory moves or reallocation."

	"(UnixProcessAccessorTestCase selector: #testEnvironmentAtPut2) run"

	| oldVal newVal resetVal count ws goodResults notFound totallyBogus |
	oldVal := accessor environmentAt: 'AAAA'.
	newVal := 'this is a test string'.
	accessor environmentAt: 'AAAA' put: newVal.
	resetVal := accessor environmentAt: 'AAAA'.
	self should: [resetVal notNil and: [resetVal isEmpty not]].
	self should: [newVal = resetVal].

	count := 50000.
	ws := WriteStream on: Array new.
	count timesRepeat: [ws nextPut: (accessor environmentAt: 'AAAA')].
	goodResults := ws contents select: [:e | e = newVal].
	notFound := ws contents select: [:e | e isNil].
	totallyBogus := ws contents select: [:e | e notNil and: [e ~= newVal]].

	"Uncomment the following to see when the problem is happening"
	"(Array with: goodResults with: notFound with: totallyBogus) inspect."

	self should: [goodResults size == count].
	self should: [notFound isEmpty].
	self should: [totallyBogus isEmpty].

	accessor environmentAt: 'AAAA' put: oldVal.
	self should: [oldVal = (accessor environmentAt: 'AAAA')]

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testFileProtectionMask [

	"(UnixProcessAccessorTestCase selector: #testFileProtectionMask) run"

	| mask |
	mask := accessor fileProtectionMask: '/bin/rm'.
	self assert: (mask isKindOf: Array).
	self assert: (mask size == 4)

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testFileStat [

	"(UnixProcessAccessorTestCase selector: #testFileStat) run"

	| stat |
	stat := accessor fileStat: '/bin/rm'.
	self assert: (stat isKindOf: Array).
	self assert: (stat size == 3).
	self assert: ((stat at: 1) isKindOf: Integer).
	self assert: ((stat at: 2) isKindOf: Integer).
	self assert: ((stat at: 3) isKindOf: Array).
	self assert: ((stat at: 3) size == 4)

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testGetStdErrHandle [

	"(UnixProcessAccessorTestCase selector: #testGetStdErrHandle) run"

	| handle |
	handle := accessor primGetStdErrHandle.
	self assert: handle notNil

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testGetStdInHandle [

	"(UnixProcessAccessorTestCase selector: #testGetStdInHandle) run"

	| handle |
	handle := accessor primGetStdInHandle.
	self assert: handle notNil

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testGetStdOutHandle [

	"(UnixProcessAccessorTestCase selector: #testGetStdOutHandle) run"

	| handle |
	handle := accessor primGetStdOutHandle.
	self assert: handle notNil

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testIsExecutable [

	"(UnixProcessAccessorTestCase selector: #testIsExecutable) run"

	self should: [accessor isExecutable: '/bin/sh'].
	self shouldnt: [accessor isExecutable: '/etc/hosts']

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testIsExecutableForUserInGroup [

	"(UnixProcessAccessorTestCase selector: #testIsExecutableForUserInGroup) run"

	self shouldnt: [OSProcess waitForCommand: 'touch /tmp/delete.me']
		raise: Warning.
	OSProcess waitForCommand: 'chmod 550 /tmp/delete.me'.
	"explicitly set file group because OS X may have set it to something other than current gid"
	OSProcess waitForCommand: 'chgrp ', accessor primGetGid asString, ' /tmp/delete.me'.
	self should: [accessor isExecutable: '/bin/sh'
					forUser: accessor primGetUid
					inGroup: accessor primGetGid].
	self shouldnt: [accessor isExecutable: '/etc/hosts'
					forUser: accessor primGetUid
					inGroup: accessor primGetGid].
	self should: [accessor isExecutable: '/tmp/delete.me'
					forUser: accessor primGetUid
					inGroup: 99999].
	self should: [accessor isExecutable: '/tmp/delete.me'
					forUser: 99999
					inGroup: accessor primGetGid].
	self shouldnt: [accessor isExecutable: '/tmp/delete.me'
					forUser: 99999
					inGroup: 99999].
	OSProcess deleteFileNamed: '/tmp/delete.me'

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testIsLockableFile [

	"(UnixProcessAccessorTestCase selector: #testIsLockableFile) debug"

	| fs result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.

	result := OSProcess accessor isLockableFile: fs.
	self should: result.

	result := OSProcess accessor lockFile: fs.
	self should: (result isKindOf: OSFileLock).
	result := OSProcess accessor isLockableFile: fs.
	self should: result.

	OSProcess accessor unlockFile: fs.
	result := OSProcess accessor isLockableFile: fs.
	self should: result.

	fs close.
	result := OSProcess accessor isLockableFile: fs.
	self shouldnt: result.
	] ensure: [fs close]

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testIsReadable [

	"(UnixProcessAccessorTestCase selector: #testIsReadable) run"

	self should: [accessor isReadable: '/bin/sh'].
	OSProcess waitForCommand: 'touch /tmp/delete.me'.
	OSProcess waitForCommand: 'chmod 440 /tmp/delete.me'.
	(Delay forMilliseconds: 200) wait.
	self should: [accessor isReadable: '/tmp/delete.me'].

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testIsReadableForUserInGroup [

	"(UnixProcessAccessorTestCase selector: #testIsReadableForUserInGroup) run"

	self shouldnt: [OSProcess waitForCommand: 'touch /tmp/delete.me']
		raise: Warning.
	OSProcess waitForCommand: 'chmod 550 /tmp/delete.me'.
	"explicitly set file group because OS X may have set it to something other than current gid"
	OSProcess waitForCommand: 'chgrp ', accessor primGetGid asString, ' /tmp/delete.me'.
	self should: [accessor isReadable: '/bin/sh'
					forUser: accessor primGetUid
					inGroup: accessor primGetGid].
	self should: [accessor isReadable: '/tmp/delete.me'
					forUser: accessor primGetUid
					inGroup: 99999].
	self should: [accessor isReadable: '/tmp/delete.me'
					forUser: 99999
					inGroup: accessor primGetGid].
	self shouldnt: [accessor isReadable: '/tmp/delete.me'
					forUser: 99999
					inGroup: 99999].
	OSProcess deleteFileNamed: '/tmp/delete.me'

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testIsWritable [

	"(UnixProcessAccessorTestCase selector: #testIsWritable) run"

	self shouldnt: [accessor isWritable: '/bin/sh'].
	OSProcess waitForCommand: 'touch /tmp/delete.me'.
	OSProcess waitForCommand: 'chmod 770 /tmp/delete.me'.
	(Delay forMilliseconds: 200) wait.
	self should: [accessor isWritable: '/tmp/delete.me'].

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testIsWritableForUserInGroup [

	"(UnixProcessAccessorTestCase selector: #testIsWritableForUserInGroup) run"

	self shouldnt: [OSProcess waitForCommand: 'touch /tmp/delete.me']
		raise: Warning.
	OSProcess waitForCommand: 'chmod 770 /tmp/delete.me'.
	"explicitly set file group because OS X may have set it to something other than current gid"
	OSProcess waitForCommand: 'chgrp ', accessor primGetGid asString, ' /tmp/delete.me'.
	self shouldnt: [accessor isWritable: '/bin/sh'
					forUser: accessor primGetUid
					inGroup: accessor primGetGid].
	self should: [accessor isWritable: '/tmp/delete.me'
					forUser: accessor primGetUid
					inGroup: 99999].
	self should: [accessor isWritable: '/tmp/delete.me'
					forUser: 99999
					inGroup: accessor primGetGid].
	self shouldnt: [accessor isWritable: '/tmp/delete.me'
					forUser: 99999
					inGroup: 99999].
	OSProcess deleteFileNamed: '/tmp/delete.me'

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testLockFile [

	"(UnixProcessAccessorTestCase selector: #testLockFile) debug"

	| fs result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.
	result := OSProcess accessor lockFile: fs.
	self should: (result isKindOf: OSFileLock).
	fs close.
	result := OSProcess accessor lockFile: fs.
	self should: (result == nil).
	] ensure: [fs close]

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testMakePipeHandles [

	"(UnixProcessAccessorTestCase selector: #testMakePipeHandles) run"

	| p |
	p := OSPipe new.
	self assert: p reader closed not.
	self assert: p writer closed not.
	p close
]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testOSFileLockLock [

	"(UnixProcessAccessorTestCase selector: #testOSFileLockLock) debug"

	| fs fileLock result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.
	fileLock := OSFileLock onFile: fs exclusive: true.
	result := fileLock lock.
	self should: (result == true).
	result := fileLock lock.
	self should: (result == true).
	fs close.
	result := fileLock lock.
	self should: (result == false).
	] ensure: [fs close]

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testOSFileLockTest [

	"(UnixProcessAccessorTestCase selector: #testOSFileLockTest) debug"

	| fs fileLock result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.
	fileLock := OSFileLock onFile: fs exclusive: true.
	result := fileLock test.
	self should: (result == true).
	result := fileLock lock.
	self should: (result == true).
	result := fileLock test.
	self should: (result == true).
	result := fileLock unlock.
	self should: (result == true).
	result := fileLock test.
	self should: (result == true).
	fs close.
	result := fileLock test.
	self should: (result == false).
	] ensure: [fs close]

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testOSFileLockUnlock [

	"(UnixProcessAccessorTestCase selector: #testOSFileLockUnlock) debug"

	| fs fileLock result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.
	fileLock := OSFileLock onFile: fs exclusive: true.
	result := fileLock unlock.
	self should: (result == true).
	result := fileLock lock.
	self should: (result == true).
	result := fileLock unlock.
	self should: (result == true).
	fs close.
	result := fileLock unlock.
	self should: (result == false).
	] ensure: [fs close]

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testOSFileRegionLockLock [

	"(UnixProcessAccessorTestCase selector: #testOSFileRegionLockLock) debug"

	| fs fileLock result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.
	fileLock := OSFileRegionLock onFile: fs from: 2 to: 4 exclusive: true.
	result := fileLock lock.
	self should: (result == true).
	result := fileLock lock.
	self should: (result == true).
	fs close.
	result := fileLock lock.
	self should: (result == false).
	] ensure: [fs close]

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testOSFileRegionLockTest [

	"(UnixProcessAccessorTestCase selector: #testOSFileRegionLockTest) debug"

	| fs fileLock result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.
	fileLock := OSFileRegionLock onFile: fs from: 2 to: 4 exclusive: true.
	result := fileLock test.
	self should: (result == true).
	result := fileLock lock.
	self should: (result == true).
	result := fileLock test.
	self should: (result == true).
	result := fileLock unlock.
	self should: (result == true).
	result := fileLock test.
	self should: (result == true).
	fs close.
	result := fileLock test.
	self should: (result == false).
	] ensure: [fs close]

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testOSFileRegionLockUnlock [

	"(UnixProcessAccessorTestCase selector: #testOSFileRegionLockUnlock) debug"

	| fs fileLock result |
	fs := OSProcess fileNamed: 'junkfile'.
	[fs nextPutAll: 'ABCDEFG'.
	fileLock := OSFileRegionLock onFile: fs from: 2 to: 4 exclusive: true.
	result := fileLock unlock.
	self should: (result == true).
	result := fileLock lock.
	self should: (result == true).
	result := fileLock unlock.
	self should: (result == true).
	fs close.
	result := fileLock unlock.
	self should: (result == false).
	] ensure: [fs close]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimArgumentAt [

	"(UnixProcessAccessorTestCase selector: #testPrimArgumentAt) run"

	| progName |
	progName := accessor primArgumentAt: 1.
	self should: [progName notNil and: [progName isEmpty not]]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimErrorMessageAt [

	"(UnixProcessAccessorTestCase selector: #testPrimErrorMessageAt) run"

	| msg |
	msg := accessor primErrorMessageAt: 1.
	self should: [msg notNil and: [msg isEmpty not]].
	msg := accessor primErrorMessageAt: 0.
	self should: [msg notNil and: [msg isEmpty not]]

]

{ #category : #'testing - fork and exec' }
UnixProcessAccessorTestCase >> testPrimForkAndExec [
	"These methods can only be tested properly from UnixProcess, which knows how
	to set up the parameters on the stack."

	"(UnixProcessAccessorTestCase selector: #testPrimForkAndExec) run"

	| p |
	self shouldnt: [p := UnixProcess command: 'ls /bin']
		raise: Warning.
	(Delay forMilliseconds: 500) wait.
	self should: [p isComplete].
	self should: [p exitStatus == 0]


]

{ #category : #'testing - fork and exec' }
UnixProcessAccessorTestCase >> testPrimGetChildExitStatus [
	"Cannot really test this here, because it needs to be wired into the interrupt
	handler. Just make sure it returns nil when there is nothing to do."

	"(UnixProcessAccessorTestCase selector: #testPrimGetChildExitStatus) run"

	| stat |
	stat := accessor primGetChildExitStatus: -1.
	self should: [stat isNil].
	stat := accessor primGetChildExitStatus: 1.
	self should: [stat isNil]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetCurrentWorkingDirectory [

	"(UnixProcessAccessorTestCase selector: #testPrimGetCurrentWorkingDirectory) run"

	| cwd |
	cwd := accessor primGetCurrentWorkingDirectory.
	self should: [cwd notNil and: [cwd isEmpty not]]
]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetEGid [

	"(UnixProcessAccessorTestCase selector: #testPrimGetEGid) run"

	| id |
	id := accessor primGetEGid.
	self should: [id isKindOf: Integer]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetEUid [

	"(UnixProcessAccessorTestCase selector: #testPrimGetEUid) run"

	| id |
	id := accessor primGetEUid.
	self should: [id isKindOf: Integer]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetGid [

	"(UnixProcessAccessorTestCase selector: #testPrimGetGid) run"

	| id |
	id := accessor primGetGid.
	self should: [id isKindOf: Integer]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetPPid [

	"(UnixProcessAccessorTestCase selector: #testPrimGetPPid) run"

	| id |
	id := accessor primGetPPid.
	self should: [id isKindOf: Integer]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetPid [

	"(UnixProcessAccessorTestCase selector: #testPrimGetPid) run"

	| id |
	id := accessor primGetPid.
	self should: [id isKindOf: Integer]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetSession [
	"As of OSPP version 4 and greater, the session ID should always be obtained from
	the interpreter. Previously it was deduced by looking at the handle of an open file."

	"(UnixProcessAccessorTestCase selector: #testPrimGetSession) run"

	| id expectedSessionSize |
	expectedSessionSize := [OSProcess accessor sizeOfInt] on: Error do: [4].
	id := OSProcess accessor primGetSession.
	self assert: (id isNil or: [id isKindOf: ByteArray]).
	id := OSProcess accessor getSessionIdentifier.
	self assert: (id isKindOf: ByteArray).
	self assert: (id size / expectedSessionSize) == 1


]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimGetUid [

	"(UnixProcessAccessorTestCase selector: #testPrimGetUid) run"

	| id |
	id := accessor primGetUid.
	self should: [id isKindOf: Integer]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testPrimUnsetEnv [

	"(UnixProcessAccessorTestCase selector: #testPrimUnsetEnv) run"

	| oldVal newVal resetVal |
	oldVal := accessor environmentAt: 'AAAA'.
	newVal := 'this is a test string'.
	accessor environmentAt: 'AAAA' put: newVal.
	resetVal := accessor environmentAt: 'AAAA'.
	self should: [resetVal notNil and: [resetVal isEmpty not]].
	self should: [newVal = resetVal].

	accessor primUnsetEnv: 'AAAA', (Character value: 0) asString.
	resetVal := accessor environmentAt: 'AAAA'.
	self should: [resetVal isNil].

	accessor environmentAt: 'AAAA' put: oldVal.
	self should: [oldVal = (accessor environmentAt: 'AAAA')]

]

{ #category : #'testing - external process access' }
UnixProcessAccessorTestCase >> testRealpath [

	"(UnixProcessAccessorTestCase selector: #testRealpath) run"

	| p |
	p := accessor realpath: '/usr/bin'.
	self should: [p notNil and: [p isEmpty not]].
	p := accessor realpath: '/bogus/path/name'.
	self should: [p isNil]

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testRedirectStdOutTo [
	"Perform a dup2() call on the standard output descriptor to assign it
	to a new file stream"

	"(UnixProcessAccessorTestCase selector: #testRedirectStdOutTo) run"

	| out aFileStream contents outFd saveFd newFileNo saveFs |
	out := OSProcess thisOSProcess stdOut.
	"save file number to allow cleanup at end of test"
	OSProcess deleteFileNamed: '/tmp/delete.2.me'.	
	saveFs := OSProcess newFileNamed: '/tmp/delete.2.me'.
	outFd := OSProcess accessor primUnixFileNumber: out fileID.
	saveFd := OSProcess accessor primUnixFileNumber: saveFs fileID.
	OSProcess accessor primDup: outFd to: saveFd.
	"Original stdout file descriptor is saved as safeFd, to be restored at end of test"

	OSProcess deleteFileNamed: '/tmp/delete.me'.	
	aFileStream := OSProcess newFileNamed: '/tmp/delete.me'.
	"nb - #contentsOfEntireFile closes the file, do not use"
	aFileStream reset.
	self assert: aFileStream upToEnd isEmpty.
	"note - do not close aFileStream as this affects actual stdout"
	out nextPutAll: 'foo'; flush.
	aFileStream reset.
	self assert: aFileStream upToEnd isEmpty.
	OSProcess thisOSProcess redirectStdOutTo: aFileStream.
	out nextPutAll: 'foo'; flush.
	aFileStream reset.
	contents := aFileStream upToEnd.
	self deny: contents isEmpty.
	self assert: contents = 'foo'. "assume noone else is using stdout right now"
	"ensure the we can still find the real stdout"
	self deny: OSProcess thisOSProcess stdOut closed.
	OSProcess thisOSProcess stdOut nextPutAll: 'bar'; flush.
	aFileStream reset.
	contents := aFileStream upToEnd.
	self deny: contents isEmpty.
	self assert: contents = 'foobar'.
	"Restore the original file number. The stdOut stream is cached in ThisOSProcess
	(and should probably be recalculated following a dup2(), so find the real handle
	with getStdOutHandle."
	newFileNo := OSProcess accessor primUnixFileNumber: OSProcess accessor getStdOutHandle.
	OSProcess accessor primDup: saveFd to: newFileNo.
	OSProcess thisOSProcess stdOut lf; nextPutAll: 'UnixProcessAccessorTestCase>>testRedirectStdOutTo - this should appear on original console stdout'; lf.
	saveFs close.
	aFileStream close.	
	OSProcess deleteFileNamed: '/tmp/delete.me'.	
	OSProcess deleteFileNamed: '/tmp/delete.2.me'.	


]

{ #category : #testing }
UnixProcessAccessorTestCase >> testSessionIdentifier [
	"This is an indirect way to make sure that the primitive for obtaining the session ID does
	not get out of kilter with respect to the method for obtaining session ID from an existing
	open file. The dangerous failure mode is if the SQFile data stucture format changes and
	OSProcess does not get updated to reflect the change.

	As of approximately Squeak 3.8 and beyond, the session id has been moved to the
	first slot of the data structure. Deducing the session ID from an open file will not
	work for a Squeak VM beyond that point, and will not work for any 64 bit VM.
	OSPP version 4.0 or higher obtains session ID from the interpreter, so this is no
	longer an issue. Skip this test for OSPP 4.0 and higher."

	"(UnixProcessAccessorTestCase selector: #testSessionIdentifier) debug"

	| installedOSPPMajorVersion |
	self should: [accessor getSessionIdentifier isKindOf: ByteArray].
	installedOSPPMajorVersion := Integer readFrom:
		(OSProcess accessor osppModuleVersionString ifNil: ['-1']) readStream.
	(installedOSPPMajorVersion >= 4)
		ifTrue: ["ignore this test"]
		ifFalse: [self should:
			[accessor getSessionIdentifierFromSourcesFile = accessor getSessionIdentifier]]

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testSignalNumbers [
	"Signal numbers as reported by UnixOSProcessPlugin. Note that some signal definitions
	are architecture dependent, with specific number assignments differing between e.g. Intel
	and Sparc. Intel architecture is assumed for this test."

	"NOTE OSPP prior to version 4.4.12 had several incorrect signal number assignments.
	Check the version level of OSPP by evaluating this expression:

		OSProcess accessor primOSProcessPluginModuleVersionString"

	self assert: OSProcess accessor primSigHupNumber = 1.
	self assert: OSProcess accessor primSigIntNumber = 2.
	self assert: OSProcess accessor primSigKillNumber = 9.
	self assert: OSProcess accessor primSigPipeNumber = 13.
	self assert: OSProcess accessor primSigQuitNumber = 3.
	self assert: OSProcess accessor primSigTermNumber = 15.
	OSProcess platformName caseOf:
		{ ['unix']		->
			[self assert: OSProcess accessor primSigUsr1Number = 10.
			 self assert: OSProcess accessor primSigUsr2Number = 12.
			 self assert: OSProcess accessor primSigChldNumber = 17.].
		   ['Mac OS']	->
			[self assert: OSProcess accessor primSigUsr1Number = 30.
			 self assert: OSProcess accessor primSigUsr2Number = 31.
			 self assert: OSProcess accessor primSigChldNumber = 20.]}
	
	

]

{ #category : #testing }
UnixProcessAccessorTestCase >> testUnixFileNumber [
	"For purposes of this test, assume that stdin and stderr have not been
	directed."

	"(UnixProcessAccessorTestCase selector: #testUnixFileNumber) run"

	| err errFileNo errHandle in inFileNo inHandle aFileStream fFileNo fHandle |
	err := OSProcess thisOSProcess stdErr.
	errHandle := err fileID.
	errFileNo := OSProcess accessor unixFileNumber: errHandle.
	self assert: errFileNo == 2.
	in := OSProcess thisOSProcess stdIn.
	inHandle := in fileID.
	inFileNo := OSProcess accessor unixFileNumber: inHandle.
	self assert: inFileNo == 0.
	aFileStream := OSProcess fileNamed: '/tmp/delete.me'.
	fHandle := aFileStream fileID.
	fFileNo := OSProcess accessor unixFileNumber: fHandle.
	self assert: fFileNo notNil.
	self assert: fFileNo > 2.
	aFileStream close


]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testUnlockFileUnixCompatible [

	"(UnixProcessAccessorTestCase selector: #testUnlockFileUnixCompatible) debug"

	| mode fs result |
	mode := OSProcess accessor emulateWin32FileLocking. "remember setting"

	fs := OSProcess fileNamed: 'junkfile'.
	[OSProcessAccessor emulateWin32FileLocking: false. "unix mode"
	fs nextPutAll: 'ABCDEFG'.
	result := OSProcess accessor unlockFile: fs.
	"On Unix, the fcntl call to unlock the file will succeed even if
	the file is not locked."
	self should: (result isKindOf: OSFileLock).

	result := OSProcess accessor lockFile: fs.
	self should: (result isKindOf: OSFileLock).
	result := OSProcess accessor unlockFile: fs.
	self should: (result isKindOf: OSFileLock).

	fs close.
	result := OSProcess accessor unlockFile: fs.
	self should: result == nil] ensure:
		[OSProcessAccessor emulateWin32FileLocking: mode.
		fs close]

]

{ #category : #'file locking' }
UnixProcessAccessorTestCase >> testUnlockFileWin32Compatible [

	"(UnixProcessAccessorTestCase selector: #testUnlockFileWin32Compatible) debug"

	| mode fs result |
	mode := OSProcess accessor emulateWin32FileLocking. "remember setting"

	fs := OSProcess fileNamed: 'junkfile'.
	[OSProcessAccessor emulateWin32FileLocking: true. "win32 mode"
	fs nextPutAll: 'ABCDEFG'.
	result := OSProcess accessor unlockFile: fs.
	self should: result == nil.

	result := OSProcess accessor lockFile: fs.
	self should: (result isKindOf: OSFileLock).
	result := OSProcess accessor unlockFile: fs.
	self should: (result isKindOf: OSFileLock).

	fs close.
	result := OSProcess accessor unlockFile: fs.
	self should: result == nil] ensure:
		[OSProcessAccessor emulateWin32FileLocking: mode.
		fs close]

]
