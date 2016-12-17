"
Test file locking with the UnixOSProcessPlugin using Unix file locking semantics. The test suite requires that OSProcess and CommandShell be loaded in the image.

These tests rely on a remote Squeak image to test file locks between cooperating Unix processes. This may be timing dependent (see #delay, set in #setUp, and cleanup in #tearDown). In case of intermittent failures, try running the failed test individually. In some cases it may be necessary to restart Squeak in order to clear leftover file locks from previous failed tests.
"
Class {
	#name : #UnixProcessUnixFileLockingTestCase,
	#superclass : #AbstractUnixProcessFileLockingTestCase,
	#category : 'OSProcess-Tests'
}

{ #category : #testing }
UnixProcessUnixFileLockingTestCase class >> isAbstract [
	"Override to true if a TestCase subclass is Abstract and should not have
	TestCase instances built from it"

	^self name = #TestCase

]

{ #category : #'testing - platform specific' }
UnixProcessUnixFileLockingTestCase >> isValidUnlockResult: result [
	"With no lock cache, the unlock requests will succeed even though there
	is no lock to be removed."	

	^ result isKindOf: OSFileLock

]

{ #category : #running }
UnixProcessUnixFileLockingTestCase >> setUp [

	"Set system to use Unix file locking semantics. The tearDown method is expected to restore the setting."

	OSProcessAccessor emulateWin32FileLocking: false.
	^ super setUp

]

{ #category : #'testing - platform specific' }
UnixProcessUnixFileLockingTestCase >> testLockPreviouslyLockedFile [
	"Locking a previously locked file is permitted"

	"(self selector: #testLockPreviouslyLockedFile) run"

	accessor lockFile: fileStream.
	self should: (accessor isLockableFile: fileStream).
	self should: ((accessor lockFile: fileStream) isKindOf: OSFileLock).
	accessor unlockFile: fileStream
]

{ #category : #'testing - platform specific' }
UnixProcessUnixFileLockingTestCase >> testLockPreviouslyLockedFileRegion [
	"Locking a previously locked file region is permitted"

	"(self selector: #testLockPreviouslyLockedFileRegion) run"

	accessor
		lockFile: fileStream
		from: 100
		to: 199
		exclusive: true.
	self should: (accessor
		isLockableFile: fileStream
		from: 100
		to: 199
		exclusive: true).
	self should: ((accessor
		lockFile: fileStream
		from: 100
		to: 199
		exclusive: true)
		isKindOf: OSFileLock).
	accessor unlockFile: fileStream
]

{ #category : #'testing - platform specific' }
UnixProcessUnixFileLockingTestCase >> testUnlockPreviouslyLockedFile [
	"The unlock operation will succeed even if no lock is in effect"

	"(self selector: #testUnlockPreviouslyLockedFile) run"

	self should: ((accessor unlockFile: fileStream) isKindOf: OSFileLock).
	accessor lockFile: fileStream.
	self should: ((accessor unlockFile: fileStream) isKindOf: OSFileLock)

]

{ #category : #'testing - platform specific' }
UnixProcessUnixFileLockingTestCase >> testUnlockPreviouslyLockedFileRegion [
	"The unlock operation will succeed even if no lock is in effect"

	"(self selector: #testUnlockPreviouslyLockedFileRegion) run"

	self should: ((accessor
		unlockFile: fileStream
		from: 100
		to: 199
		exclusive: true) isKindOf: OSFileLock).
	accessor
		lockFile: fileStream
		from: 100
		to: 199
		exclusive: true.
	self should: ((accessor
		unlockFile: fileStream
		from: 100
		to: 199
		exclusive: true) isKindOf: OSFileLock)

]
