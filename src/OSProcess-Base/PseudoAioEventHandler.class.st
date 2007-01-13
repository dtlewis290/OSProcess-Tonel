"
PseudoAioEventHandler is a replacement for AioEventHandler for use when an AioPlugin is not present. It creates a polling loop by generating #changed: events periodically. With a real AioEventHandler, events are generated only when actual IO activity occurs, while the PseudoAioEventHandler produces regularly timed events regardless of whether any actual IO changes have happened.
"
Class {
	#name : #PseudoAioEventHandler,
	#superclass : #Model,
	#instVars : [
		'eventGenerator'
	],
	#category : #'OSProcess-AIO'
}

{ #category : #'initialize-release' }
PseudoAioEventHandler >> close [
	"When the FileStream or Socket handled by this aio handler is closed,
	it should send #close to this handler."

	eventGenerator ifNotNil: [eventGenerator terminate]
]

{ #category : #accessing }
PseudoAioEventHandler >> eventGenerator [
	"Answer the value of eventGenerator"

	^ eventGenerator ifNil: [eventGenerator _ self eventGeneratorProcess]
]

{ #category : #'initialize-release' }
PseudoAioEventHandler >> eventGeneratorProcess [
	"A process that generates periodic #changed events"

	| d |
	d _ Delay forMilliseconds: 125.
	^ [[self changed.
	d wait] repeat] fork
]

{ #category : #'initialize-release' }
PseudoAioEventHandler >> initialize [

	self eventGenerator.
	^ super initialize
]
