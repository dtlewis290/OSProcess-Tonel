"
I describe an addressable region of contiguous bytes in an external file. On platforms that support file locking, an OSFileRegionLock is used to specify a portion of the file to be locked.

"
Class {
	#name : #OSFileRegionLock,
	#superclass : #OSFileLock,
	#instVars : [
		'interval'
	],
	#category : 'OSProcess-Base'
}

{ #category : #'instance creation' }
OSFileRegionLock class >> onFile: aFileStream from: start to: end exclusive: writeLockFlag [
	"A region representing part of a file"

	^ self onFile: aFileStream interval: (start to: end) exclusive: writeLockFlag

]

{ #category : #'instance creation' }
OSFileRegionLock class >> onFile: aFileStream interval: anInterval exclusive: writeLockFlag [
	"A region representing part of a file"

	^ super new onFile: aFileStream interval: anInterval exclusive: writeLockFlag

]

{ #category : #comparing }
OSFileRegionLock >> = aFileRegion [

	^ (super = aFileRegion) and: [self interval = aFileRegion interval]

]

{ #category : #comparing }
OSFileRegionLock >> hash [

	^ (super hash + self interval hash) hashMultiply

]

{ #category : #accessing }
OSFileRegionLock >> interval [
	"Answer the value of interval"

	^ interval
]

{ #category : #accessing }
OSFileRegionLock >> interval: anObject [
	"Set the value of interval"

	interval := anObject
]

{ #category : #private }
OSFileRegionLock >> length [
	^ self interval size
]

{ #category : #private }
OSFileRegionLock >> offset [
	^ self interval first
]

{ #category : #'initialize-release' }
OSFileRegionLock >> onFile: aFileStream interval: anInterval exclusive: writeLockFlag [

	self onFile: aFileStream exclusive: writeLockFlag.
	self interval: anInterval.
]

{ #category : #comparing }
OSFileRegionLock >> overlaps: aFileLock [
	"Call #overlapsRegion: on aFileLock since we know we're a region but we don't know whether aFileLock is"
	
	^ aFileLock overlapsRegion: self
]

{ #category : #comparing }
OSFileRegionLock >> overlapsRegion: aFileRegionLock [
	^ (super overlapsRegion: aFileRegionLock) and: [(self interval intersection: aFileRegionLock interval) isEmpty not]
]
