"
This test case was provided by Julian Fitzell. It provides more file locking tests in addition to those in UnitProcessFileLockingTestCase.
"
Class {
	#name : #UnixProcessFileLockTestCase,
	#superclass : #TestCase,
	#instVars : [
		'fileStream'
	],
	#category : #'OSProcess-Tests'
}

{ #category : #asserting }
UnixProcessFileLockTestCase >> assertLock: lock1 lock: lock2 conflicts: aBoolean [
	self assert: (lock1 conflictsWith: lock2) = aBoolean.
	self assert: (lock2 conflictsWith: lock1) = aBoolean.
]

{ #category : #data }
UnixProcessFileLockTestCase >> entireExclusiveLock [
	^ OSFileLock onFile: fileStream exclusive: true
]

{ #category : #data }
UnixProcessFileLockTestCase >> entireSharedLock [
	^ OSFileLock onFile: fileStream exclusive: false
]

{ #category : #accessing }
UnixProcessFileLockTestCase >> fileStream [
	^ fileStream
]

{ #category : #data }
UnixProcessFileLockTestCase >> regionExclusiveLock [
	^ self regionLockFrom: 10 to: 20 exclusive: true
]

{ #category : #data }
UnixProcessFileLockTestCase >> regionLockFrom: from to: to exclusive: exclusive [
	^ OSFileRegionLock onFile: fileStream from: from to: to exclusive: exclusive
]

{ #category : #data }
UnixProcessFileLockTestCase >> regionSharedLock [
	^ self regionLockFrom: 10 to: 20 exclusive: false
]

{ #category : #running }
UnixProcessFileLockTestCase >> setUp [
	OSProcess deleteFileNamed: 'junkfile'.
	fileStream := OSProcess fileNamed: 'junkfile'.
]

{ #category : #running }
UnixProcessFileLockTestCase >> tearDown [
	fileStream close.
	OSProcess deleteFileNamed: fileStream fullName
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testDistinctExclusiveRegionWithExclusiveRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: true)
		lock: (self regionLockFrom: 30 to: 40 exclusive: true)
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testDistinctExclusiveRegionWithSharedRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: true)
		lock: (self regionLockFrom: 30 to: 40 exclusive: false)
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testDistinctSharedRegionWithExclusiveRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: false)
		lock: (self regionLockFrom: 30 to: 40 exclusive: true)
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testDistinctSharedRegionWithSharedRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: false)
		lock: (self regionLockFrom: 30 to: 40 exclusive: false)
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testEntireExclusiveWithEntireExclusive [
	self
		assertLock: self entireExclusiveLock
		lock: self entireExclusiveLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testEntireExclusiveWithExclusiveRegion [
	self
		assertLock: self entireExclusiveLock
		lock: self regionExclusiveLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testEntireExclusiveWithSharedRegion [
	self
		assertLock: self entireExclusiveLock
		lock: self regionSharedLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testEntireSharedWithEntireExclusive [
	self
		assertLock: self entireSharedLock
		lock: self entireExclusiveLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testEntireSharedWithEntireShared [
	self
		assertLock: self entireSharedLock
		lock: self entireSharedLock
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testEntireSharedWithExclusiveRegion [
	self
		assertLock: self entireSharedLock
		lock: self regionExclusiveLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testEntireSharedWithSharedRegion [
	self
		assertLock: self entireSharedLock
		lock: self regionSharedLock
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testExclusiveRegionWithExclusiveRegion [
	self
		assertLock: self regionExclusiveLock
		lock: self regionExclusiveLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testIdenticalExclusiveRegionWithExclusiveRegion [
	self
		assertLock: self regionExclusiveLock
		lock: self regionExclusiveLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testIdenticalSharedRegionWithExclusiveRegion [
	self
		assertLock: self regionSharedLock
		lock: self regionExclusiveLock
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testIdenticalSharedRegionWithSharedRegion [
	self
		assertLock: self regionSharedLock
		lock: self regionSharedLock
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testOverlappingExclusiveRegionWithExclusiveRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: true)
		lock: (self regionLockFrom: 20 to: 30 exclusive: true)
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testOverlappingExclusiveRegionWithSharedRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: true)
		lock: (self regionLockFrom: 20 to: 30 exclusive: false)
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testOverlappingSharedRegionWithExclusiveRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: false)
		lock: (self regionLockFrom: 20 to: 30 exclusive: true)
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testOverlappingSharedRegionWithSharedRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 20 exclusive: false)
		lock: (self regionLockFrom: 20 to: 30 exclusive: false)
		conflicts: false
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testSupersetExclusiveRegionWithExclusiveRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 40 exclusive: true)
		lock: (self regionLockFrom: 20 to: 30 exclusive: true)
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testSupersetExclusiveRegionWithSharedRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 40 exclusive: true)
		lock: (self regionLockFrom: 20 to: 30 exclusive: false)
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testSupersetSharedRegionWithExclusiveRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 40 exclusive: false)
		lock: (self regionLockFrom: 20 to: 30 exclusive: true)
		conflicts: true
]

{ #category : #testing }
UnixProcessFileLockTestCase >> testSupersetSharedRegionWithSharedRegion [
	self
		assertLock: (self regionLockFrom: 10 to: 40 exclusive: false)
		lock: (self regionLockFrom: 20 to: 30 exclusive: false)
		conflicts: false
]
