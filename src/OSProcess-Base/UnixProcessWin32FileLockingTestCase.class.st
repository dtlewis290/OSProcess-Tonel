"
Test file locking with the UnixOSProcessPlugin using Windows file locking semantics. The test suite requires that OSProcess and CommandShell be loaded in the image.

These tests rely on a remote Squeak image to test file locks between cooperating Unix processes. This may be timing dependent (see #delay, set in #setUp, and cleanup in #tearDown). In case of intermittent failures, try running the failed test individually. In some cases it may be necessary to restart Squeak in order to clear leftover file locks from previous failed tests.
"
Class {
	#name : #UnixProcessWin32FileLockingTestCase,
	#superclass : #AbstractUnixProcessFileLockingTestCase,
	#category : #'OSProcess-Tests'
}

{ #category : #testing }
UnixProcessWin32FileLockingTestCase class >> isAbstract [
	"Override to true if a TestCase subclass is Abstract and should not have
	TestCase instances built from it"

	^self name = #TestCase

]

{ #category : #'testing - platform specific' }
UnixProcessWin32FileLockingTestCase >> isValidUnlockResult: result [
	"With a lock cache, the unlock requests will fail when if there
	is no lock to be removed."	

	^ result == nil

]

{ #category : #running }
UnixProcessWin32FileLockingTestCase >> setUp [

	"Set system to use Windows file locking semantics. The tearDown method is expected to restore the setting."

	OSProcessAccessor emulateWin32FileLocking: true.
	^ super setUp

]

{ #category : #'testing - platform specific' }
UnixProcessWin32FileLockingTestCase >> testLockPreviouslyLockedFile [
	"A previously locked file cannot be locked."

	"(self selector: #testLockPreviouslyLockedFile) run"

	accessor lockFile: fileStream.
	self shouldnt: (accessor isLockableFile: fileStream).
	self should: (accessor lockFile: fileStream) isNil.
	accessor unlockFile: fileStream
]

{ #category : #'testing - platform specific' }
UnixProcessWin32FileLockingTestCase >> testLockPreviouslyLockedFileRegion [
	"A previously locked file region cannot be locked."

	"(self selector: #testLockPreviouslyLockedFileRegion) run"

	accessor
		lockFile: fileStream
		from: 100
		to: 199
		exclusive: true.
	self shouldnt: (accessor
		isLockableFile: fileStream
		from: 100
		to: 199
		exclusive: true).
	self should: ((accessor
		lockFile: fileStream
		from: 100
		to: 199
		exclusive: true) isNil).
	accessor unlockFile: fileStream
]

{ #category : #'testing - platform specific' }
UnixProcessWin32FileLockingTestCase >> testUnlockPreviouslyLockedFile [
	"The unlock operation will fail if lock is in effect"

	"(self selector: #testUnlockPreviouslyLockedFile) run"

	self shouldnt: ((accessor unlockFile: fileStream) isKindOf: OSFileLock).
	accessor lockFile: fileStream.
	self should: ((accessor unlockFile: fileStream) isKindOf: OSFileLock).
	self shouldnt: ((accessor unlockFile: fileStream) isKindOf: OSFileLock)

]

{ #category : #'testing - platform specific' }
UnixProcessWin32FileLockingTestCase >> testUnlockPreviouslyLockedFileRegion [
	"The unlock operation will fail if a lock is in effect"

	"(self selector: #testUnlockPreviouslyLockedFileRegion) run"

	self shouldnt: ((accessor
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
		exclusive: true) isKindOf: OSFileLock).
	self shouldnt: ((accessor
		unlockFile: fileStream
		from: 100
		to: 199
		exclusive: true) isKindOf: OSFileLock)

]
