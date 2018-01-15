"
Test file locking with the UnixOSProcessPlugin. The test suite requires that OSProcess and CommandShell be loaded in the image.

These tests rely on a remote Squeak image to test file locks between cooperating Unix processes. This may be timing dependent (see #delay, set in #setUp, and cleanup in #tearDown). In case of intermittent failures, try running the failed test individually. In some cases it may be necessary to restart Squeak in order to clear leftover file locks from previous failed tests.
"
Class {
	#name : #AbstractUnixProcessFileLockingTestCase,
	#superclass : #TestCase,
	#instVars : [
		'accessor',
		'fileStream',
		'delay',
		'remoteProcess',
		'initialCompatibilitySetting'
	],
	#category : #'OSProcess-Tests'
}

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase class >> isAbstract [
	"Override to true if a TestCase subclass is Abstract and should not have
	TestCase instances built from it"

	^ true
]

{ #category : #accessing }
AbstractUnixProcessFileLockingTestCase >> delay [
	"Answer the value of delay"

	^ delay
]

{ #category : #'remote image commands' }
AbstractUnixProcessFileLockingTestCase >> doRemote: remoteBlock doLocal: localBlock [
	"Evaluate remoteBlock in a remote Squeak image. While the remote Squeak is
	still running, evaluate localBlock. When done, terminate the remote Squeak
	image and answer the result of evaluating localBlock."

	"self new
		doRemote: [OSProcess thisOSProcess stdOut nextPutAll: 'hello from child Squeak';
						nextPut: Character lf]
		doLocal: [(Delay forSeconds: 1) wait.
						OSProcess thisOSProcess stdOut nextPutAll: 'hello from parent Squeak';
					nextPut: Character lf]"

	| result |
	self shouldnt: [remoteProcess := OSProcess thisOSProcess forkHeadlessSqueak]
		raise: Warning.
	self assert: remoteProcess notNil. "Fail if fork did not succeed"
	(remoteProcess == OSProcess thisOSProcess)
		ifTrue:
			["remote child Squeak"
			remoteBlock value]
		ifFalse:
			["parent Squeak"
			[[remoteProcess isRunning] whileFalse: [self delay wait].
			self delay wait.
			result := localBlock value]
				ensure:	[remoteProcess terminate.
					[remoteProcess isComplete] whileFalse: [self delay wait].
					self delay wait.
					result]].
	^ result

]

{ #category : #failures }
AbstractUnixProcessFileLockingTestCase >> expectedFailures [
	^UnixOSProcessAccessor basicNew safeToForkSqueak
		ifTrue: [#()]
		ifFalse: [#(	testCooperatingProcesses01
					testCooperatingProcesses02
					testCooperatingProcesses03
					testCooperatingProcesses04
					testCooperatingProcesses05
					testFailFileLockOnLockedFile
					testFailLockOnLockedOverlappedRegion
					testFailLockOnLockedRegion
					testFailLockOnLockedSupersetRegion
					testFailRegionLockOnLockedFile
					testLockEntireFileForWrite01
					testLockEntireFileForWrite02
					testLockEntireFileForWrite03
					testLockEntireFileForWrite04
					testLockEntireFileForWrite05
					testLockEntireFileForWrite06
					testLockRegionForRead01
					testLockRegionForRead02
					testLockRegionForWrite01
					testLockRegionForWrite02
					testLockRegionForWrite03
					testLockRegionForWrite04
					testLockRegionForWrite05
					testLockRegionForWrite06
					testLockRegionForWrite07
					testLockRegionForWrite08
					testNoFailLockOnAdjacentLockedRegions
					testNoFailLockOnDifferentLockedRegion)]
]

{ #category : #initialize }
AbstractUnixProcessFileLockingTestCase >> initialize [

	initialCompatibilitySetting
		ifNil: [initialCompatibilitySetting := OSProcess accessor emulateWin32FileLocking]
]

{ #category : #'testing - platform specific' }
AbstractUnixProcessFileLockingTestCase >> isValidUnlockResult: result [

	self subclassResponsibility

]

{ #category : #'remote image commands' }
AbstractUnixProcessFileLockingTestCase >> quitImage [

	fileStream close.
	OSProcess snapshot: false andQuit: true

]

{ #category : #running }
AbstractUnixProcessFileLockingTestCase >> setUp [

	(self respondsTo: #timeout: ) "Recent Squeak images with test case timeout"
		ifTrue: [self perform: #timeout: with: 30].
	delay := Delay forMilliseconds: 150.
	accessor := ThisOSProcess accessor.
	OSProcess deleteFileNamed: 'junkfile'.
	fileStream := OSProcess fileNamed: 'junkfile'.
	1000 timesRepeat: (fileStream nextPutAll: 'hello world ').

]

{ #category : #running }
AbstractUnixProcessFileLockingTestCase >> tearDown [

	| d |
	OSProcessAccessor emulateWin32FileLocking: initialCompatibilitySetting.
	d := Delay forMilliseconds: 50.
	fileStream close.
	remoteProcess ifNotNil:
		[remoteProcess terminate.
		[remoteProcess isComplete] whileFalse: [d wait].
		remoteProcess := nil]

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testCooperatingProcesses01 [
	"Two cooperating Squeak processes using file region locking to coordinate their
	writes to a shared file."

	"(self selector: #testCooperatingProcesses01) run"

	| result |
	result := self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 120) notNil]) ifNil: [self quitImage].
			fileStream position: 100.
			fileStream nextPutAll: 'THIS '; flush.
			accessor unlockFile: fileStream from: 100 to: 120.
			delay wait.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			fileStream position: 108.
			fileStream nextPutAll: 'A '; flush.
			accessor unlockFile: fileStream from: 108 to: 120.
			delay wait.
			self quitImage]
		doLocal:
			[self assert: (self tryUntil: [(accessor lockFile: fileStream from: 104 to: 120) notNil]).
			fileStream position: 105.
			fileStream nextPutAll: 'is '; flush.
			accessor unlockFile: fileStream from: 104 to: 120.
			delay wait.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			fileStream position: 110.
			fileStream nextPutAll: 'test '; flush.
			accessor unlockFile: fileStream from: 108 to: 120.
			delay wait].
	self tryUntil: [(accessor lockFile: fileStream from: 100 to: 140) notNil].
	fileStream position: 100.
	result := fileStream next: 14.
	accessor unlockFile: fileStream from: 100 to: 140.
	self assert: result = 'THIS is A test'

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testCooperatingProcesses02 [
	"Two cooperating Squeak processes using file region locking to coordinate their
	writes to a shared file."

	"(self selector: #testCooperatingProcesses02) run"

	| result |
	result := self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 120) notNil]) ifNil: [self quitImage].
			fileStream position: 100.
			fileStream nextPutAll: 'THIS 11111111111111111111111'; flush.
			accessor unlockFile: fileStream from: 100 to: 120.
			delay wait; wait; wait.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			fileStream position: 108.
			fileStream nextPutAll: 'A 3333333333333333333333333'; flush.
			accessor unlockFile: fileStream from: 108 to: 120.
			self quitImage]
		doLocal:
			[self assert: (self tryUntil: [(accessor lockFile: fileStream from: 104 to: 120) notNil]).
			fileStream position: 105.
			fileStream nextPutAll: 'IS 2222222222222222222222222'; flush.
			accessor unlockFile: fileStream from: 104 to: 120.
			delay wait; wait; wait.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			fileStream position: 110.
			fileStream nextPutAll: 'TEST 4444444444444444444444'; flush.
			accessor unlockFile: fileStream from: 108 to: 120].
	self tryUntil: [(accessor lockFile: fileStream from: 100 to: 140) notNil].
	fileStream position: 100.
	result := fileStream next: 17.
	accessor unlockFile: fileStream from: 100 to: 140.
	self assert: result = 'THIS IS A TEST 44'

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testCooperatingProcesses03 [
	"Two cooperating Squeak processes using file region locking to coordinate their
	writes to a shared file."

	"(self selector: #testCooperatingProcesses03) run"

	| result |
	result := self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 120) notNil]) ifNil: [self quitImage].
			fileStream position: 100.
			fileStream nextPutAll: 'THIS 11111111111111111111111'; flush.
			accessor unlockFile: fileStream from: 100 to: 120.
			delay wait; wait; wait.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			fileStream position: 108.
			fileStream nextPutAll: 'A 3333333333333333333333333'; flush.
			accessor unlockFile: fileStream from: 108 to: 120.
			self quitImage]
		doLocal:
			[self assert: (self tryUntil: [(accessor lockFile: fileStream from: 104 to: 120) notNil]).
			fileStream position: 105.
			fileStream nextPutAll: 'IS 2222222222222222222222222'; flush.
			accessor unlockFile: fileStream from: 104 to: 120.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			fileStream position: 110.
			fileStream nextPutAll: 'TEST 4444444444444444444444'; flush.
			accessor unlockFile: fileStream from: 108 to: 120].
	self tryUntil: [(accessor lockFile: fileStream from: 100 to: 140) notNil].
	fileStream position: 100.
	result := fileStream next: 17.
	accessor unlockFile: fileStream from: 100 to: 140.
	self assert: result = 'THIS IS 22TEST 44'

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testCooperatingProcesses04 [
	"Two cooperating Squeak processes using file region locking to coordinate their
	writes to a shared file."

	"(self selector: #testCooperatingProcesses04) run"

	| result |
	result := self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 120) notNil]) ifNil: [self quitImage].
			delay wait.
			fileStream position: 100.
			fileStream nextPutAll: 'THIS 11111111111111111111111'; flush.
			accessor unlockFile: fileStream from: 100 to: 120.
			delay wait.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			delay wait.
			fileStream position: 108.
			fileStream nextPutAll: 'A 3333333333333333333333333'; flush.
			accessor unlockFile: fileStream from: 108 to: 120.
			delay wait.
			self quitImage]
		doLocal:
			[self assert: (self tryUntil: [(accessor lockFile: fileStream from: 104 to: 120) notNil]).
			delay wait.
			fileStream position: 105.
			fileStream nextPutAll: 'IS 2222222222222222222222222'; flush.
			accessor unlockFile: fileStream from: 104 to: 120.
			delay wait.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			fileStream position: 110.
			fileStream nextPutAll: 'TEST 4444444444444444444444; flush'.
			accessor unlockFile: fileStream from: 108 to: 120].
	self tryUntil: [(accessor lockFile: fileStream from: 100 to: 140) notNil].
	fileStream position: 100.
	result := fileStream next: 17.
	accessor unlockFile: fileStream from: 100 to: 140.
	self assert: result = 'THIS IS A TEST 44'

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testCooperatingProcesses05 [
	"Two cooperating Squeak processes using file region locking to coordinate their
	writes to a shared file."

	"(self selector: #testCooperatingProcesses05) run"

	| result |
	result := self
		doRemote:
			[OSProcess thisOSProcess stdOut nextPutAll: 'starting remote squeak requesting lock on 100 to 120';
				nextPut: Character lf.
			(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 120) notNil]) ifNil: [self quitImage].
			OSProcess thisOSProcess stdOut nextPutAll: 'remote squeak lock acquired on 100 to 120'; nextPut: Character lf; flush.
			fileStream position: 100.
			fileStream nextPutAll: 'THIS '; flush.
			OSProcess thisOSProcess stdOut nextPutAll: 'remote squeak releasing lock on 100 to 120'; nextPut: Character lf; flush.
			accessor unlockFile: fileStream from: 100 to: 120.
			OSProcess thisOSProcess stdOut nextPutAll: 'remote squeak lock released on 100 to 120'; nextPut: Character lf; flush.
			delay wait.
			OSProcess thisOSProcess stdOut nextPutAll: 'remote squeak requesting lock on 108 to: 120'; nextPut: Character lf; flush.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			OSProcess thisOSProcess stdOut nextPutAll: 'remote squeak lock acquired on 108 to: 120'; nextPut: Character lf; flush.
			fileStream position: 108.
			fileStream nextPutAll: 'A '; flush.
			OSProcess thisOSProcess stdOut nextPutAll: 'remote squeak releasing lock on 108 to: 120'; nextPut: Character lf; flush.
			accessor unlockFile: fileStream from: 108 to: 120.
			OSProcess thisOSProcess stdOut nextPutAll: 'remote squeak lock released on 108 to: 120'; nextPut: Character lf; flush.
			delay wait.
			self quitImage]
		doLocal:
			[OSProcess thisOSProcess stdOut nextPutAll: 'starting local squeak requesting lock on 104 to: 120';
				nextPut: Character lf.
			self assert: (self tryUntil: [(accessor lockFile: fileStream from: 104 to: 120) notNil]).
			OSProcess thisOSProcess stdOut nextPutAll: 'local squeak lock acquired on 104 to: 120'; nextPut: Character lf; flush.
			fileStream position: 105.
			fileStream nextPutAll: 'IS '; flush.
			OSProcess thisOSProcess stdOut nextPutAll: 'local squeak releasing lock on 104 to: 120'; nextPut: Character lf; flush.
			accessor unlockFile: fileStream from: 104 to: 120.
			OSProcess thisOSProcess stdOut nextPutAll: 'local squeak lock released on 104 to: 120'; nextPut: Character lf; flush.
			delay wait.
			OSProcess thisOSProcess stdOut nextPutAll: 'local squeak requesting lock on 108 to: 120'; nextPut: Character lf; flush.
			self tryUntil: [(accessor lockFile: fileStream from: 108 to: 120) notNil].
			OSProcess thisOSProcess stdOut nextPutAll: 'local squeak lock acquired on 108 to: 120'; nextPut: Character lf; flush.
			fileStream position: 110.
			fileStream nextPutAll: 'TEST '; flush.
			OSProcess thisOSProcess stdOut nextPutAll: 'local squeak releasing lock on 108 to: 120'; nextPut: Character lf; flush.
			accessor unlockFile: fileStream from: 108 to: 120.
			OSProcess thisOSProcess stdOut nextPutAll: 'local squeak lock released on 108 to: 120'; nextPut: Character lf; flush.
			delay wait].
	self tryUntil: [(accessor lockFile: fileStream from: 100 to: 140) notNil].
	fileStream position: 100.
	result := fileStream next: 14.
	accessor unlockFile: fileStream from: 100 to: 140.
	self assert: result = 'THIS IS A TEST'

]

{ #category : #'testing - exclusive locking' }
AbstractUnixProcessFileLockingTestCase >> testFailFileLockOnLockedFile [
	"Two cooperating Squeak processes using mandatory file locking. When
	child Squeak takes a lock on a region, lock attempt in parent Squeak will
	fail."

	"(self selector: #testFailFileLockOnLockedFile) run"

	self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream) notNil]) ifNil: [self quitImage].
			delay wait; wait; wait.
			accessor unlockFile: fileStream.
			self quitImage]
		doLocal:
			[self should: [
				10 timesRepeat: [ "lock and unlock until failure due to child taking the lock"
					accessor lockFile: fileStream
							exclusive: true
							ifFail: [self error: '#lockFile failed because child Squeak now holds a lock'].
					accessor unlockFile: fileStream. "release lock to allow child to acquire it"
					delay wait]]
				raise: Error
				description: '#lockFile failed because child Squeak now holds a lock']

]

{ #category : #'testing - exclusive locking' }
AbstractUnixProcessFileLockingTestCase >> testFailLockOnLockedOverlappedRegion [
	"Two cooperating Squeak processes using mandatory file locking. When
	child Squeak takes a lock on a region, lock attempt in parent Squeak will
	fail. Locked regions overlap by one character."

	"(self selector: #testFailLockOnLockedOverlappedRegion) run"

	self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 104) notNil]) ifNil: [self quitImage].
			delay wait; wait; wait.
			accessor unlockFile: fileStream from: 100 to: 104.
			self quitImage]
		doLocal:
			[self should: [
				10 timesRepeat: [ "lock and unlock until failure due to child taking the lock"
					accessor lockFile: fileStream
							from: 104
							to: 120
							exclusive: true
							ifFail: [self error: '#lockFile failed because child Squeak now holds a lock'].
					accessor unlockFile: fileStream from: 104 to: 120. "release lock to allow child to acquire it"
					delay wait]]
				raise: Error
				description: '#lockFile failed because child Squeak now holds a lock']

]

{ #category : #'testing - exclusive locking' }
AbstractUnixProcessFileLockingTestCase >> testFailLockOnLockedRegion [
	"Two cooperating Squeak processes using mandatory file locking. When
	child Squeak takes a lock on a region, lock attempt in parent Squeak will
	fail."

	"(self selector: #testFailLockOnLockedRegion) run"

	self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 120) notNil]) ifNil: [self quitImage].
			delay wait; wait; wait.
			accessor unlockFile: fileStream from: 100 to: 120.
			self quitImage]
		doLocal:
			[self should: [
				10 timesRepeat: [ "lock and unlock until failure due to child taking the lock"
					accessor lockFile: fileStream
							from: 100
							to: 120
							exclusive: true
							ifFail: [self error: '#lockFile failed because child Squeak now holds a lock'].
					accessor unlockFile: fileStream from: 100 to: 120. "release lock to allow child to acquire it"
					delay wait]]
				raise: Error
				description: '#lockFile failed because child Squeak now holds a lock']

]

{ #category : #'testing - exclusive locking' }
AbstractUnixProcessFileLockingTestCase >> testFailLockOnLockedSupersetRegion [
	"Two cooperating Squeak processes using mandatory file locking. When
	child Squeak takes a lock on a region, lock attempt in parent Squeak will
	fail. Fail when requesting a lock on a subset of the locked region."

	"(self selector: #testFailLockOnLockedSupersetRegion) run"

	self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 140) notNil]) ifNil: [self quitImage].
			delay wait; wait; wait.
			accessor unlockFile: fileStream from: 100 to: 140.
			self quitImage]
		doLocal:
			[self should: [
				10 timesRepeat: [ "lock and unlock until failure due to child taking the lock"
					accessor lockFile: fileStream
							from: 104
							to: 120
							exclusive: true
							ifFail: [self error: '#lockFile failed because child Squeak now holds a lock'].
					accessor unlockFile: fileStream from: 104 to: 120. "release lock to allow child to acquire it"
					delay wait]]
				raise: Error
				description: '#lockFile failed because child Squeak now holds a lock']

]

{ #category : #'testing - exclusive locking' }
AbstractUnixProcessFileLockingTestCase >> testFailRegionLockOnLockedFile [
	"Two cooperating Squeak processes using mandatory file locking. When
	child Squeak takes a lock on a file, the region lock attempt in parent
	Squeak will fail."

	"(self selector: #testFailRegionLockOnLockedFile) run"

	self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream) notNil]) ifNil: [self quitImage].
			delay wait; wait; wait.
			accessor unlockFile: fileStream.
			self quitImage]
		doLocal:
			[self should: [
				10 timesRepeat: [ "lock and unlock until failure due to child taking the lock"
					accessor lockFile: fileStream
							from: 100
							to: 120
							exclusive: true
							ifFail: [self error: '#lockFile failed because child Squeak now holds a lock'].
					accessor unlockFile: fileStream from: 100 to: 120. "release lock to allow child to acquire it"
					delay wait]]
				raise: Error
				description: '#lockFile failed because child Squeak now holds a lock']

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockEntireFileForWrite01 [
	"Local lock request should succeed"

	"(self selector: #testLockEntireFileForWrite01) run"

	| result |
	result := self
		doRemote: [nil]
		doLocal: [accessor lockFile: fileStream].
	self delay wait; wait.
	self assert: (result isKindOf: OSFileLock).
	result := accessor unlockFile: fileStream.
	self assert: (result isKindOf: OSFileLock)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockEntireFileForWrite02 [
	"Local lock request should fail"

	"(self selector: #testLockEntireFileForWrite02) run"

	| result |
	result := self
		doRemote:
			[accessor lockFile: fileStream]
		doLocal: [accessor lockFile: fileStream].
	self delay wait; wait.
	self assert: result isNil.
	"Region is in the cache as a result of the (failed) lock request. This is legitimate
	because the lock exists in some other image, so we want to mark it as locked
	locally. However, it is not quite correct because the remote lock may pertain to
	a different but overlapping region. Nevertheless, this seems like reasonable
	behavior."
	result := accessor unlockFile: fileStream.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockEntireFileForWrite03 [
	"Local lock request should succeed"

	"(self selector: #testLockEntireFileForWrite03) run"

	| result |
	result := self
		doRemote:
			[accessor lockFile: fileStream.
			accessor unlockFile: fileStream]
		doLocal:
			[accessor lockFile: fileStream].
	self delay wait; wait.
	self assert: (result isKindOf: OSFileLock).
	result := accessor unlockFile: fileStream.
	self assert: (result isKindOf: OSFileLock)
]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockEntireFileForWrite04 [
	"Local lock should be available"

	"(self selector: #testLockEntireFileForWrite04) run"

	| result |
	result := self
		doRemote: [nil]
		doLocal: [accessor isLockableFile: fileStream].
	self delay wait; wait.
	self should: result.
	"No lock on the region, so the unlock should fail."
	result := accessor unlockFile: fileStream.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockEntireFileForWrite05 [
	"Local lock should be available"

	"(self selector: #testLockEntireFileForWrite05) run"

	| result |
	result := self
		doRemote:
			[accessor lockFile: fileStream]
		doLocal: [accessor isLockableFile: fileStream].
	self delay wait; wait.
	self shouldnt: result.
	"No local lock in the cache for this file, so the unlock call will appear to fail.
	Actually, it will have passed the unlock request through to the operating system,
	and it will actually unlock the file."
	result := accessor unlockFile: fileStream.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockEntireFileForWrite06 [
	"Local lock should be available"

	"(self selector: #testLockEntireFileForWrite06) run"

	| result |
	result := self
		doRemote:
			[accessor lockFile: fileStream.
			accessor unlockFile: fileStream]
		doLocal:
			[accessor isLockableFile: fileStream].
	self delay wait; wait.
	self should: result.
	"No local lock in the cache for this file, so the unlock call will appear to fail.
	Actually, it will have passed the unlock request through to the operating system,
	but it will have no effect because the file was never locked."
	result := accessor unlockFile: fileStream.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #'fail blocks' }
AbstractUnixProcessFileLockingTestCase >> testLockFileIfFail [

	"(self selector: #testLockFileIfFail) run"

	| fail |
	fail := false.
	accessor lockFile: fileStream ifFail: [fail := true].
	self shouldnt: fail.
	fileStream close.
	accessor lockFile: fileStream ifFail: [fail := true].
	self should: fail

]

{ #category : #'fail blocks' }
AbstractUnixProcessFileLockingTestCase >> testLockFileRegionIfFail [

	"(self selector: #testLockFileRegionIfFail) run"

	| fail |
	fail := false.
	accessor
		lockFile: fileStream from: 100 to: 199 exclusive: true
		ifFail: [fail := true].
	self shouldnt: fail.
	fileStream close.
	accessor
		lockFile: fileStream from: 100 to: 199 exclusive: true
		ifFail: [fail := true].
	self should: fail.
	accessor
		lockFile: fileStream from: 100 to: 199
		ifFail: [fail := true].
	self should: fail

]

{ #category : #'testing - platform specific' }
AbstractUnixProcessFileLockingTestCase >> testLockPreviouslyLockedFile [

	self subclassResponsibility
]

{ #category : #'testing - platform specific' }
AbstractUnixProcessFileLockingTestCase >> testLockPreviouslyLockedFileRegion [

	self subclassResponsibility
]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForRead01 [
	"Read lock, the local lock request should succeed"

	"(self selector: #testLockRegionForRead01) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: false]
		doLocal: [accessor lockFile: fileStream from: 100 to: 199 exclusive: false].
	self delay wait; wait.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199)).
	result := accessor unlockFile: fileStream from: 100 to: 199 exclusive: false.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199))
]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForRead02 [
	"Read lock, the local lock request should fail when requesting a write lock"

	"(self selector: #testLockRegionForRead02) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor lockFile: fileStream from: 100 to: 199 exclusive: false].
	self delay wait; wait.
	self assert: result isNil.
	result := accessor unlockFile: fileStream from: 100 to: 199.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite01 [
	"Local lock request should succeed"

	"(self selector: #testLockRegionForWrite01) run"

	| result |
	result := self
		doRemote: [nil]
		doLocal: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true].
	self delay wait; wait.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199)).
	result := accessor unlockFile: fileStream from: 100 to: 199.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199))
]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite02 [
	"Write lock, the local lock request should fail"

	"(self selector: #testLockRegionForWrite02) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true].
	self delay wait; wait.
	self assert: result isNil.
	"Lock is not in the local cache, so unlock will appear to fail. Actually, the region
	will be unlocked."
	accessor unlockFile: fileStream from: 100 to: 199.
	self assert: result isNil.

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite03 [
	"Write lock, nonoverlapping regions, the lock check should succeed"

	"(self selector: #testLockRegionForWrite03) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor isLockableFile: fileStream from: 200 to: 299 exclusive: true].
	self delay wait; wait.
	self assert: result.
	result := accessor unlockFile: fileStream from: 200 to: 299.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite04 [
	"Write lock, overlapping regions, the local lock request should fail"

	"(self selector: #testLockRegionForWrite04) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor lockFile: fileStream from: 150 to: 249 exclusive: true].
	self delay wait; wait.
	self assert: result isNil.
	result := accessor unlockFile: fileStream from: 150 to: 249.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite05 [
	"Write lock, nonoverlapping regions, the local lock request should succeed"

	"(self selector: #testLockRegionForWrite05) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor lockFile: fileStream from: 200 to: 299 exclusive: true].
	self delay wait; wait.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (200 to: 299)).
	result := accessor unlockFile: fileStream from: 200 to: 299.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (200 to: 299))
]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite06 [
	"Write lock, overlapping regions, the local lock request should fail"

	"(self selector: #testLockRegionForWrite06) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor lockFile: fileStream from: 199 to: 199 exclusive: true].
	self delay wait; wait.
	self assert: result isNil.
	result := accessor unlockFile: fileStream from: 199 to: 199.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite07 [
	"Write lock, overlapping regions, the lock check should fail"

	"(self selector: #testLockRegionForWrite07) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor isLockableFile: fileStream from: 100 to: 199 exclusive: true].
	self delay wait; wait.
	self deny: result.
	result := accessor unlockFile: fileStream from: 100 to: 199.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testLockRegionForWrite08 [
	"Write lock, overlapping regions, the lock check should fail"

	"(self selector: #testLockRegionForWrite08) run"

	| result |
	result := self
		doRemote: [accessor lockFile: fileStream from: 100 to: 199 exclusive: true]
		doLocal: [accessor isLockableFile: fileStream from: 150 to: 299 exclusive: true].
	self delay wait; wait.
	self deny: result.
	result := accessor unlockFile: fileStream from: 150 to: 299.
	self assert: (self isValidUnlockResult: result)

]

{ #category : #'testing - exclusive locking' }
AbstractUnixProcessFileLockingTestCase >> testNoFailLockOnAdjacentLockedRegions [
	"Two cooperating Squeak processes using mandatory file locking. When
	child Squeak takes a lock on a region, lock attempt in parent Squeak will
	fail. No failure occurs when the regions are adjacent but do not overlap."

	"(self selector: #testNoFailLockOnAdjacentLockedRegions) run"

	self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 100 to: 103) notNil]) ifNil: [self quitImage].
			delay wait; wait; wait.
			accessor unlockFile: fileStream from: 100 to: 103.
			self quitImage]
		doLocal:
			[self shouldnt: [
				10 timesRepeat: [ "lock and unlock until failure due to child taking the lock"
					accessor lockFile: fileStream
							from: 104
							to: 120
							exclusive: true
							ifFail: [self error: '#lockFile failed because child Squeak now holds a lock'].
					accessor unlockFile: fileStream from: 104 to: 120. "release lock to allow child to acquire it"
					delay wait]]
				raise: Error]

]

{ #category : #'testing - exclusive locking' }
AbstractUnixProcessFileLockingTestCase >> testNoFailLockOnDifferentLockedRegion [
	"Two cooperating Squeak processes using mandatory file locking. When
	child Squeak takes a lock on a region, lock attempt in parent Squeak will
	fail. No failure occurs if the regions are different and do not overlap."

	"(self selector: #testNoFailLockOnDifferentLockedRegion) run"

	self
		doRemote:
			[(self tryUntil: [(accessor lockFile: fileStream from: 50 to: 80) notNil]) ifNil: [self quitImage].
			delay wait; wait; wait.
			accessor unlockFile: fileStream from: 50 to: 80.
			self quitImage]
		doLocal:
			[self shouldnt: [
				10 timesRepeat: [ "lock and unlock until failure due to child taking the lock"
					accessor lockFile: fileStream
							from: 104
							to: 120
							exclusive: true
							ifFail: [self error: '#lockFile failed because child Squeak now holds a lock'].
					accessor unlockFile: fileStream from: 104 to: 120. "release lock to allow child to acquire it"
					delay wait]]
				raise: Error]

]

{ #category : #'fail blocks' }
AbstractUnixProcessFileLockingTestCase >> testUnlockFileIfFail [

	"(self selector: #testUnlockFileIfFail) run"

	| fail |
	fail := false.
	accessor lockFile: fileStream ifFail: [fail := true].
	self shouldnt: fail.
	accessor unlockFile: fileStream ifFail: [fail := true].
	self shouldnt: fail.
	fileStream close.
	accessor unlockFile: fileStream ifFail: [fail := true].
	self should: fail

]

{ #category : #'fail blocks' }
AbstractUnixProcessFileLockingTestCase >> testUnlockFileRegionIfFail [

	"(self selector: #testUnlockFileRegionIfFail) run"

	| fail |
	fail := false.
	accessor
		lockFile: fileStream from: 100 to: 199 exclusive: true
		ifFail: [fail := true].
	self shouldnt: fail.
	accessor
		unlockFile: fileStream from: 100 to: 199 exclusive: true
		ifFail: [fail := true].
	self shouldnt: fail.
	fileStream close.
	accessor
		unlockFile: fileStream from: 100 to: 199 exclusive: true
		ifFail: [fail := true].
	self should: fail.
	accessor
		unlockFile: fileStream from: 100 to: 199
		ifFail: [fail := true].
	self should: fail


]

{ #category : #'testing - platform specific' }
AbstractUnixProcessFileLockingTestCase >> testUnlockPreviouslyLockedFile [

	self subclassResponsibility
]

{ #category : #'testing - platform specific' }
AbstractUnixProcessFileLockingTestCase >> testUnlockPreviouslyLockedFileRegion [

	self subclassResponsibility
]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testWin32LockEmulation01 [
	"Make sure the cache does what is expected, and that it can be disabled
	Expect non-exclusive read locks to to succeed."

	"(self selector: #testWin32LockEmulation01) run"

	| result |
	accessor class emulateWin32FileLocking: true.
	result := accessor lockFile: fileStream from: 100 to: 199 exclusive: false.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199)).
	result := accessor lockFile: fileStream from: 100 to: 199 exclusive: false.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199)).
	result := accessor unlockFile: fileStream from: 100 to: 199 exclusive: false.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199))

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testWin32LockEmulation02 [
	"Make sure the cache does what is expected, and that it can be disabled.
	Expect exclusive read-write locks to be protected by the cache."

	"(self selector: #testWin32LockEmulation02) run"

	| result |
	accessor class emulateWin32FileLocking: true.
	result := accessor lockFile: fileStream from: 100 to: 199 exclusive: true.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199)).
	result := accessor lockFile: fileStream from: 100 to: 199 exclusive: true.
	self assert: result isNil.
	result := accessor unlockFile: fileStream from: 100 to: 199 exclusive: true.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199))

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testWin32LockEmulation03 [
	"Make sure the cache does what is expected, and that it can be disabled.
	Expect the cache to protect the file even if we open a second stream"

	"(self selector: #testWin32LockEmulation03) run"

	| result stream2 |
	accessor class emulateWin32FileLocking: true.
	result := accessor lockFile: fileStream from: 100 to: 199 exclusive: true.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199)).
	stream2 := OSProcess fileNamed: 'junkfile'.
	[result := accessor lockFile: stream2 from: 100 to: 199 exclusive: true.
	self assert: result isNil]
		ensure: [stream2 close].
	result := accessor unlockFile: fileStream from: 100 to: 199 exclusive: true.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199))

]

{ #category : #testing }
AbstractUnixProcessFileLockingTestCase >> testWin32LockEmulation04 [
	"Make sure the cache does what is expected, and that it can be disabled.
	Expect the cache to allow a lock after the stream has been closed (since the OS will have freed its lock)"

	"(self selector: #testWin32LockEmulation04) run"

	| result stream2 |
	accessor class emulateWin32FileLocking: true.
	stream2 := OSProcess fileNamed: 'junkfile'.
	[result := accessor lockFile: stream2 from: 100 to: 199 exclusive: true.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199))]
		ensure: [stream2 close].
	result := accessor lockFile: fileStream from: 100 to: 199 exclusive: true.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199)).
	result := accessor unlockFile: fileStream from: 100 to: 199 exclusive: true.
	self assert: (result isKindOf: OSFileRegionLock).
	self assert: (result interval = (100 to: 199))
]

{ #category : #private }
AbstractUnixProcessFileLockingTestCase >> tryUntil: aBlock [
	"Repeat until block evaluates true, but do not get in an infinite loop if a primitive is failing"

	| result |
	10 timesRepeat:
		[result := aBlock value.
		result ifTrue: [^ result].
		delay wait].
	^ result

]
