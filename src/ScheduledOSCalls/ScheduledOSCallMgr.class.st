"
Class to hold instances of ScheduledOSCall and run them. Click ? between instance and class buttoms to read more.

An instance of this class is used to hold a group of similar ScheduledOSCall instances.  What constitutes similar is completely subjective.  You can put all of your scheduled OS calls in one instance.  But if you have more than one group of similar calls, keeping them in sperate instances of this class can be helpful.

The class side of this class keeps a dictionary of instances of this class (by their title) that are currently running (checking their instances of ScheduledOSCall for items that are due to run).  This could have been done with a singleton of a third class but then the class side is a singleton so I went with it.  The dictionary allows you to find a given instance of this class (a group of similar ScheduledOSCall instances) and see how it (and its charges) are doing.

Below is a sample.  Please note it builds calls to the LIRC irsend command.  This is only an example.  The ScheduledOSCall and ScheduledOSCalls classes don't know or care about irsend.  They are OS command agnostic.

	| schedule |
	schedule := ScheduledOSCallMgr title: 'Lou''s recordings'.
	schedule addRequest: (ScheduledOSCall fromString: 'Up the volume | 13:29 | #Everyday | irsend SEND_START Explorer4200 vUp; sleep 5; irsend SEND_STOP Explorer4200 vUp').
	schedule addRequest: (ScheduledOSCall fromString: 'Charlie Rose (13) | 13:30 | #Weekdays | irsend SEND_ONCE Explorer4200 0 0 1 3').
	schedule addRequest: (ScheduledOSCall fromString: 'Science (170) | 20:00 | #Tuesday | irsend SEND_ONCE Explorer4200 0 1 7 0').
	schedule addRequest: (ScheduledOSCall fromString: 'Continuum (48) | 20:00 | #Monday | irsend SEND_ONCE Explorer4200 0 0 4 8').
	schedule run.
	schedule requests.

Inspecting the code above will set up an instance of ScheduledOSCalls with four (4) instances of ScheduledOSCall.  The last line will allow you to see the status of each instance of ScheduledOSCall.

There are other ways to create instances of ScheduledOSCall.  The one shown above was chosen to simplify the example.

Use ScheduledOSCalls>terminateAll to terminate all instances of ScheduledOSCallMgr..
Inspect ScheduledOSCalls>runningScheduledOSCallMgr to see the dictionary of ScheduledOSCallMgr.

To find the instance of ScheduledOSCallMgr managing a specific group of ScheduledOSCallMgr and see its requests, inspect the following:

| schedule |
schedule := ScheduledOSCalls at: 'Lou''s recordings'.
schedule ifNotNil: [:s | s requests].

Look at instance variables: osCallTestDelay, osCallTestLimit and osCallRetryLimit to see how command calls to OSProcess>command: (callOS: and callOS) are managed.


"
Class {
	#name : #ScheduledOSCallMgr,
	#superclass : #Object,
	#instVars : [
		'requests',
		'process',
		'title',
		'osCallTestDelay',
		'osCallTestLimit',
		'osCallRetryLimit'
	],
	#classVars : [
		'OSCallRetryLimitDefault',
		'OSCallTestDelayDefault',
		'OSCallTestLimitDefault',
		'RunningScheduledOSCallMgrs'
	],
	#category : #ScheduledOSCalls
}

{ #category : #Control }
ScheduledOSCallMgr class >> addRunningScheduledOSCallMgr: aScheduledOSCallMgr [
	"Add the ScheduledOSCallMgr."

	self runningScheduledOSCallMgrs at: aScheduledOSCallMgr title put: aScheduledOSCallMgr.
	^RunningScheduledOSCallMgrs.

]

{ #category : #Control }
ScheduledOSCallMgr class >> at: aString [
	"Answer the ScheduledOSCallMgr at the title."

	^self runningScheduledOSCallMgrs at: aString ifAbsent: [].

]

{ #category : #Control }
ScheduledOSCallMgr class >> clearRunningScheduledOSCallMgrs [
	"A collection of ScheduledOSCallMgr objects."

	RunningScheduledOSCallMgrs := Dictionary new.

]

{ #category : #'class variables' }
ScheduledOSCallMgr class >> osCallRetryLimitDefault [
	"Answer the default value for osCallRetryLimit, the number of time we try the command."

	OSCallRetryLimitDefault isNil ifTrue: [OSCallRetryLimitDefault := 10].
	^OSCallRetryLimitDefault.

]

{ #category : #'class variables' }
ScheduledOSCallMgr class >> osCallRetryLimitDefault: anInt [
	"Answer the default value for osCallRetryLimit, the number of time we try the command."

	OSCallRetryLimitDefault := anInt.

]

{ #category : #'class variables' }
ScheduledOSCallMgr class >> osCallTestDelayDefault [
	"Answer the default value for osCallTestDelay, the time in milliseconds between testing to see if the command finished."

	OSCallTestDelayDefault isNil ifTrue: [OSCallTestDelayDefault := 200].
	^OSCallTestDelayDefault.

]

{ #category : #'class variables' }
ScheduledOSCallMgr class >> osCallTestDelayDefault: anInt [
	"Answer the default value for osCallTestDelay, the time in milliseconds between testing to see if the command finished."

	OSCallTestDelayDefault := anInt.

]

{ #category : #'class variables' }
ScheduledOSCallMgr class >> osCallTestLimitDefault [
	"Answer the default value for osCallTestLimit, number of time we test to see if the command finished."

	OSCallTestLimitDefault isNil ifTrue: [OSCallTestLimitDefault := 50].
	^OSCallTestLimitDefault.

]

{ #category : #'class variables' }
ScheduledOSCallMgr class >> osCallTestLimitDefault: anInt [
	"Answer the default value for osCallTestLimit, number of time we test to see if the command finished."

	OSCallTestLimitDefault := anInt.

]

{ #category : #'class variables' }
ScheduledOSCallMgr class >> runningScheduledOSCallMgrs [
	"A collection of ScheduledOSCallMgr objects."

	RunningScheduledOSCallMgrs isNil ifTrue: [RunningScheduledOSCallMgrs := Dictionary new].
	^RunningScheduledOSCallMgrs.

]

{ #category : #Control }
ScheduledOSCallMgr class >> terminateAll [
	"Terminate all the ScheduledOSCallMgr objects."

	self runningScheduledOSCallMgrs do: [:s | s terminate; clearRequests].
	self clearRunningScheduledOSCallMgrs.

]

{ #category : #'class initialization' }
ScheduledOSCallMgr class >> title: aString [
	"Create a new instance with the title."

	^(self new) title: aString; yourself.

]

{ #category : #comparing }
ScheduledOSCallMgr >> = aScheduledOSCallMgr [
	"Answer true if our titles are the same."

	^self title sameAs: aScheduledOSCallMgr title.

]

{ #category : #Control }
ScheduledOSCallMgr >> addAllRequests: aCollection [
	"Add all the requests to our requests.  A dictionary of instances of ScheduledOSCall that we run at their time."

	aCollection do: [:r | self requests addRequest: r].

]

{ #category : #Control }
ScheduledOSCallMgr >> addRequest: aRequest [
	"Add the request to our requests.  A dictionary of instances of ScheduledOSCall that we run at their time."

	self requests at: aRequest when put: aRequest.

]

{ #category : #Control }
ScheduledOSCallMgr >> callOS: item [
	"Tell the item to call the OS to run the command."
	"The command may take a while to run, so we loop on checking to see if it finished
		delaying for osCallTestDelay milliseconds between each try
		but give up after osCallTestCnt attempts."
	"If it didn't finish successfully, we try again for osCallTestCnt times.  The item will re-schedule itself."
	| delay lastOSCallResult tryCnt checkCnt |

	delay := Delay forMilliseconds: self osCallTestDelay.
	tryCnt := 0.
	[
		lastOSCallResult := item callOS.
		checkCnt := 0.
		[
			delay wait.
			(lastOSCallResult isComplete) | (checkCnt > self osCallTestLimit).
		] whileFalse: [checkCnt := checkCnt + 1].
		(lastOSCallResult succeeded) | (tryCnt > self osCallRetryLimit).
	] whileFalse: [tryCnt := tryCnt + 1].

]

{ #category : #Control }
ScheduledOSCallMgr >> clearRequests [
	"Clear our requests.  Set them inactive to insure they don't run."

	requests ifNotNil: [:rqs | rqs do: [:r | r hold]].
	requests := Dictionary new.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> osCallRetryLimit [
	"The number of times to retry command if it failed (or we timed out checking it)."

	osCallRetryLimit isNil ifTrue: [osCallRetryLimit := self class osCallRetryLimitDefault].
	^osCallRetryLimit.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> osCallRetryLimit: anInt [
	"The number of times to retry command if it failed (or we timed out checking it)."

	osCallRetryLimit := anInt.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> osCallTestDelay [
	"The milliseconds to delay between checks for completion."

	osCallTestDelay isNil ifTrue: [osCallTestDelay := self class osCallTestDelayDefault].
	^osCallTestDelay.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> osCallTestDelay: anInt [
	"The milliseconds to delay between checks for completion."

	osCallTestDelay := anInt.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> osCallTestLimit [
	"The number of times to check for completion."

	osCallTestLimit isNil ifTrue: [osCallTestLimit := self class osCallTestLimitDefault].
	^osCallTestLimit.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> osCallTestLimit: anInt [
	"The number of times to check for completion."

	osCallTestLimit := anInt.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> printOn: aStream [
	"Print about us on the stream."

	aStream nextPutAll: 'Title: '; nextPutAll: self title; cr.
	requests do: [:r | r printOn: aStream].

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> process [
	"Answer the process running the OS calls."

	^process.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> requests [
	"Answer our requests.  A dictionary of instances of ScheduledOSCall that we run at their time."

	requests isNil ifTrue: [requests := Dictionary new].
	^requests.

]

{ #category : #Control }
ScheduledOSCallMgr >> run [
	"Define and run the process to run the OS calls."

	^self runAt: Processor userBackgroundPriority.

]

{ #category : #Control }
ScheduledOSCallMgr >> runAt: priority [
	"Define and run the process to run the OS calls.  Re-schedule inactive items when they should run."

	self terminate.
	process := [ | delay today time lastDate |
		delay := Delay forSeconds: 1.
		lastDate := Date today.
		[
			today := Date today.
			"If the date has changed, we may not have been running for a while, we should reschedule things."
			"This will also happen at midnight but scheduling won't hurt."
			(today = lastDate) ifFalse: [self requests do: [:r | r schedule]].
			lastDate := today.
			time := Time now.
			self requests do: [:r |
				((r date = today) & (r time < time)) ifTrue: [
					r active ifTrue: [self callOS: r] ifFalse: [r schedule].
				].
			].
			true.		
		] whileTrue: [delay wait].
	] forkAt: priority named: self title.
	self class addRunningScheduledOSCallMgr: self.
	^process.

]

{ #category : #Control }
ScheduledOSCallMgr >> terminate [
	"Terminate the process running the OS calls."

	process ifNotNil: [:p | p terminate].
	process := nil.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> title [
	"Answer our title."

	title isNil ifTrue: [title := '?'].
	^title.

]

{ #category : #InstanceVariables }
ScheduledOSCallMgr >> title: aString [
	"Set our title."

	title := aString.

]
