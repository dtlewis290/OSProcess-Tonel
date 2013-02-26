"
Data for sending commands to the OS at a given time.  Click ? between instance and class buttoms to read more.

Create an instance of this class for each command (and parameters) and the time to send the command and scheduling cycle.

See the method comments for more info on each.

Also see the class comment of ScheduledOSCallMgr for info on how it holds instances of this class and how it calls OSProcess with the command at the appointed time.
"
Class {
	#name : #ScheduledOSCall,
	#superclass : #Object,
	#instVars : [
		'date',
		'time',
		'dayOfWeek',
		'command',
		'title',
		'lastOSCallResult',
		'active'
	],
	#category : #ScheduledOSCalls
}

{ #category : #'instance creation' }
ScheduledOSCall class >> fromString: aString [
	"Create a new instance from the string.  The string is in four parts seperated by pipes '|'."
	"title | time | dayOfWeek | command"
	| parts title time dayOfWeek command |

	parts := (aString subStrings: '|') collect: [:ss | ss withBlanksTrimmed].
	(parts size >= 1) ifTrue: [title := parts first].
	(parts size >= 2) ifTrue: [time := ([Time fromString: parts second] on: Error do: [])].
	(parts size >= 3) ifTrue: [dayOfWeek := parts third onlyLetters asLowercase capitalized asSymbol].
	(parts size >= 4) ifTrue: [command := parts fourth].

	^(self new) title: title; time: time; dayOfWeek: dayOfWeek; command: command; schedule; yourself.

]

{ #category : #'instance creation' }
ScheduledOSCall class >> title: aString time: aTime dayOfWeek: aSymbol command: commandString [
	"Create a new instance and set some values."

	^(self new) title: aString; time: aTime; dayOfWeek: aSymbol; command: commandString; schedule; yourself.

]

{ #category : #'instance creation' }
ScheduledOSCall class >> title: aString timeString: timeString dayOfWeek: aSymbol command: commandString [
	"Create a new instance and set some values."
	| time |

	time := [Time fromString: timeString] on: Error do: [].
	^(self new) title: aString; time: time; dayOfWeek: aSymbol; command: commandString; schedule; yourself.

]

{ #category : #Control }
ScheduledOSCall >> = aScheduledOSCall [
	"Answer tue if we have the same hash."

	^self hash = aScheduledOSCall hash.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> activate [
	"Set active true, if the command is active it will be run at the defined time."

	active := true.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> active [
	"If true, the command is active and will be run at the defined time."

	active isNil ifTrue: [active := true].
	^active.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> active: aBoolean [
	"If true, the command is active and will be run at the defined time."

	active := aBoolean.

]

{ #category : #Control }
ScheduledOSCall >> callOS [
	"Call the OS to run the command."

	lastOSCallResult := OSProcess command: self command.
	self schedule.
	^lastOSCallResult.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> command [
	"Command to send to the OS."

	command isNil ifTrue: [command := 'help'].
	^command.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> command: aString [
	"The command to be sent to the OS."

	command := aString.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> date [
	"The date the command should be sent next."

	date isNil ifTrue: [date := Date today].
	^date.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> date: aDate [
	"The date the command should be sent next."

	date := aDate.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> dayOfWeek [
	"A symbol defining the day-of-week the command should be sent."
	"#Sunday #Monday #Tuesday #Wednesday #Thursday #Friday #Saturday #Weekdays #Weekend #Everyday"

	dayOfWeek isNil ifTrue: [dayOfWeek := self date weekday].
	^dayOfWeek.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> dayOfWeek: aSymbol [
	"A symbol defining the day-of-week the command should be sent."
	"#Sunday #Monday #Tuesday #Wednesday #Thursday #Friday #Saturday #Weekdays #Weekend #Everyday"

	(#(#Sunday #Monday #Tuesday #Wednesday #Thursday #Friday #Saturday #Weekdays #Weekend #Everyday)
		includes: aSymbol) ifTrue: [dayOfWeek := aSymbol].

]

{ #category : #Control }
ScheduledOSCall >> everyDay [
	"Answer true if the dayOfWeek symbol is #Everyday"

	^self dayOfWeek = #Everyday.

]

{ #category : #Control }
ScheduledOSCall >> hash [
	"Answer our hash"

	^self when hash.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> hold [
	"Set active false, if the command is active it will be sent at the defined time."

	active := false.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> lastOSCallResult [
	"The result of the last OSCall."

	^lastOSCallResult.

]

{ #category : #Control }
ScheduledOSCall >> onDay [
	"Answer true if the dayOfWeek symbol is one of the weekdays"
	"#Sunday #Monday #Tuesday #Wednesday #Thursday #Friday #Saturday."

	^Week dayNames includes: self dayOfWeek.

]

{ #category : #Control }
ScheduledOSCall >> onWeekdays [
	"Answer true if the dayOfWeek symbol is #Weekdays."

	^self dayOfWeek = #Weekdays.

]

{ #category : #Control }
ScheduledOSCall >> onWeekend [
	"Answer true if the dayOfWeek symbol is #Weekend."

	^self dayOfWeek = #Weekend.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> printOn: aStream [
	"Print our values on the stream."
	| showSeconds |

	aStream
		nextPutAll: 'Title: "'; nextPutAll: self title; nextPutAll: '" - Is '; nextPutAll: (self active ifTrue: ['Active'] ifFalse: ['InActive']); cr;
		nextPutAll: 'Command: "'; nextPutAll: self command; nextPutAll: '"'; cr.

	self everyDay ifTrue: [aStream nextPutAll: 'Every Day'].
	self onDay ifTrue: [aStream nextPutAll: 'Every: '; nextPutAll: self dayOfWeek asString].
	self onWeekdays ifTrue: [aStream nextPutAll: 'On weekdays'].
	self onWeekend ifTrue: [aStream nextPutAll: 'On weekends'].

	aStream nextPutAll: ', next on: '.
	self date dayMonthYearDo: [:d :m :y |
		aStream nextPutAll: (Date nameOfMonth: m); nextPutAll: ' '.
		d printOn: aStream.
		aStream nextPutAll: ', '.
		y printOn: aStream.
	].
	aStream nextPutAll: ' at: '.
	showSeconds := self time asDuration seconds ~= 0.
	self time print24: false showSeconds: showSeconds on: aStream..
	aStream cr.
	lastOSCallResult notNil ifTrue: [aStream nextPutAll: 'Last attempt: ';
		nextPutAll: (lastOSCallResult succeeded ifTrue: ['Succeded'] ifFalse: ['Failed'])
	] ifFalse: [aStream nextPutAll: 'Not attempted yet'].
	aStream cr; cr.

]

{ #category : #Control }
ScheduledOSCall >> schedule [
	"Adjust the date the command should be sent next.  This will be sometime later than the current date/time."
	| dateTime now weekdayIndex |

	dateTime := DateAndTime date: self date time: self time.
	weekdayIndex := date weekdayIndex.
	now := DateAndTime now.

	[
		(dateTime > now) &
			((self onDay & (date weekday = self dayOfWeek)) |
			(self onWeekdays & (weekdayIndex between: 2 and: 6)) |
			(self onWeekend & ((weekdayIndex = 1) | (weekdayIndex = 7))) |
			(self everyDay))
	] whileFalse: [
		date := date addDays: 1.
		dateTime := DateAndTime date: self date time: self time.
		weekdayIndex := date weekdayIndex.
	].

]

{ #category : #InstanceVariables }
ScheduledOSCall >> time [
	"The time the command should be sent."

	time isNil ifTrue: [time := Time now].
	^time.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> time: aTime [
	"The time the command should be sent."

	time := aTime.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> title [
	"The title of this request."

	title isNil ifTrue: [title := '?'].
	^title.

]

{ #category : #InstanceVariables }
ScheduledOSCall >> title: aString [
	"The title of this request."

	title := aString.

]

{ #category : #Control }
ScheduledOSCall >> when [
	"Answer a string that is a short description of when we should run.  It is used to identify us."
	| stream showSeconds |

	stream := ReadWriteStream on: ''.
	stream nextPutAll: self dayOfWeek; nextPutAll: ' at '.
	showSeconds := (self time asDuration seconds = 0) not.
	self time print24: false showSeconds: showSeconds on: stream..
	^stream contents.

]
