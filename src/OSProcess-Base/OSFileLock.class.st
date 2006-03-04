"
I describe the region representing the entire addressable space of an external file, including regions that have not yet been allocated for use by the file. On platforms that support file locking, an OSFileLock is used to describe a lock on the entire file.

"
Class {
	#name : #OSFileLock,
	#superclass : #Object,
	#instVars : [
		'fileStream',
		'exclusive'
	],
	#category : #'OSProcess-Base'
}

{ #category : #'instance creation' }
OSFileLock class >> onFile: aFileStream exclusive: writeLockFlag [
	"A region representing the whole file"

	^ super new onFile: aFileStream exclusive: writeLockFlag

]

{ #category : #comparing }
OSFileLock >> = aFileLock [
	^ (self species = aFileLock species)
		and: [self fileStream == aFileLock fileStream]
		and: [self exclusive == aFileLock exclusive]
]

{ #category : #'conflict testing' }
OSFileLock >> conflictsWith: otherFileLock [
	^ (self isExclusive or: [otherFileLock isExclusive])
		and: [self overlaps: otherFileLock]
]

{ #category : #accessing }
OSFileLock >> exclusive [
	"Answer the value of exclusive. Default is true, indicating a read-write lock
	as opposed to a shared read lock."

	^ exclusive ifNil: [exclusive _ true].
]

{ #category : #accessing }
OSFileLock >> exclusive: anObject [
	"Set the value of exclusive"

	exclusive _ anObject
]

{ #category : #accessing }
OSFileLock >> fileStream [
	"Answer the value of fileStream"

	^ fileStream
]

{ #category : #accessing }
OSFileLock >> fileStream: anObject [
	"Set the value of fileStream"

	fileStream _ anObject
]

{ #category : #comparing }
OSFileLock >> hash [
	^ (self fileStream hash + self exclusive hash) hashMultiply
]

{ #category : #testing }
OSFileLock >> isActive [
	^ self fileStream closed not
]

{ #category : #testing }
OSFileLock >> isExclusive [
	^ self exclusive
]

{ #category : #private }
OSFileLock >> length [
	^ 0
]

{ #category : #'system locking' }
OSFileLock >> lock [
	| handle result |
	handle _ ThisOSProcess accessor handleFromFileStream: self fileStream.
	result _ ThisOSProcess accessor
		primLockFileRegion: handle
		offset: self offset
		length: self length
		exclusive: self isExclusive.
		
	^ (result == -1 or: [result isNil]) not
]

{ #category : #private }
OSFileLock >> offset [
	^ 0
]

{ #category : #'initialize-release' }
OSFileLock >> onFile: aFileStream exclusive: writeLockFlag [

	self fileStream: aFileStream.
	self exclusive: writeLockFlag

]

{ #category : #comparing }
OSFileLock >> overlaps: aFileLock [
	"Answer true if the receiver represents an addressable region that overlaps aFileLock"
	
	^ aFileLock fileStream fullName = self fileStream fullName
]

{ #category : #comparing }
OSFileLock >> overlapsRegion: aFileRegionLock [
	^ aFileRegionLock fileStream fullName = self fileStream fullName
]

{ #category : #'system locking' }
OSFileLock >> test [
	| handle result |
	handle _ ThisOSProcess accessor handleFromFileStream: self fileStream.
	result _ ThisOSProcess accessor
		primTestLockableFileRegion: handle
		offset: self offset
		length: self length
		exclusive: self isExclusive.
		
	^ (result == -1 or: [result isNil]) not ifTrue: [result first]

]

{ #category : #'system locking' }
OSFileLock >> unlock [
	| handle result |
	handle _ ThisOSProcess accessor handleFromFileStream: self fileStream.
	result _ ThisOSProcess accessor
		primUnlockFileRegion: handle
		offset: self offset
		length: self length.

	^ (result == -1 or: [result isNil]) not
]
