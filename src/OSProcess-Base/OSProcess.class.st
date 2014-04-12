"
I represent an operating system process, such as the process in which the Squeak VM is currently running. My subclasses implement system specific features for Unix, Windows, MacOS, or other operating systems.

"
Class {
	#name : #OSProcess,
	#superclass : #Object,
	#instVars : [
		'pid'
	],
	#classVars : [
		'UseIOHandle'
	],
	#category : #'OSProcess-Base'
}

{ #category : #'external process access' }
OSProcess class >> accessor [
	"Answer an OSProcessAccessor for this OS process."

	^ self thisOSProcess processAccessor

]

{ #category : #sUnit }
OSProcess class >> allTestResults [
	"Run all available sUnit tests and save the results in a file named
	'OSProcessTestResults-<platform>.txt'. Display results on the Transcript as
	tests are run. Answer a string with the test results."

	"OSProcess allTestResults"

	| resultsFileName writeStream resultString results fs problems result wordSize |
	self listLoadedModules
		detect: [:e | '*OSProcessPlugin*' match: e]
		ifNone: [self notify: 'no OSProcessPlugin loaded'].
	wordSize := (Smalltalk respondsTo: #wordSize)
		ifTrue: [Smalltalk wordSize]
		ifFalse: [4].
	resultsFileName := 'OSProcessTestResults-' , OSProcess platformName , '-' ,
		(wordSize * 8) asString , 'bitImage-' ,
		(OSProcess accessor sizeOfPointer * 8) asString , 'bitHw.txt'.
	[fs := FileStream newFileNamed: resultsFileName.
	problems := false.
	writeStream := WriteStream on: String new.
	writeStream nextPutAll: self authorInitials , ' running OSProcess unit tests ' , TimeStamp now asString; cr.
	writeStream nextPutAll: 'OSProcess platformName => ' , OSProcess platformName; cr.
	writeStream nextPutAll: 'OSProcess platformSubtype => ' , OSProcess platformSubtype; cr.
	writeStream nextPutAll: 'OSProcess osVersion => ' , OSProcess osVersion; cr.
	writeStream nextPutAll: 'OSProcess vmVersion => ' , OSProcess vmVersion; cr.
	writeStream nextPutAll: 'size of C int: OSProcess accessor sizeOfInt ==> ' , OSProcess accessor sizeOfInt asString; cr.
	writeStream nextPutAll: 'size of C pointer: OSProcess accessor sizeOfPointer ==> ' , OSProcess accessor sizeOfPointer asString; cr.
	writeStream nextPutAll: 'OSProcess versionInformation asString => ' , OSProcess versionInformation asString; cr.
	Transcript show: writeStream contents.
	(((Class allSubInstances select: [:class | #'OSProcess-Tests' = class category]) ,
		(Class allSubInstances select: [:class | #'CommandShell-Tests' = class category]))
			reject: [:class | 'Abstract*' match: class name])
		do: [:testCase | 
			writeStream nextPutAll: 'running tests in ' , testCase name; cr.
			Transcript show: 'running tests in ' , testCase name; cr.
			testCase allTestSelectors
				do: [:testSelector |
					OSProcess thisOSProcess stdOut nextPutAll:
						testCase name, '>>',testSelector, String lf; flush.
					resultString := (testSelector
								-> ([result := (testCase selector: testSelector) run.
									result hasPassed
										ifFalse: [problems := true].
									result]
										on: Error
										do: [:ex | problems := true.
											'caught exception ' , ex printString])) printString.
					writeStream nextPutAll: resultString; cr.
					Transcript show: resultString; cr]].
	problems
		ifTrue: [writeStream nextPutAll: 'one or more problems found'; cr.
			Transcript show: 'one or more problems were found, see results file'; cr]
		ifFalse: [writeStream nextPutAll: 'all tests completed without problems'; cr.
			Transcript show: 'all tests completed without problems'; cr].
	results := writeStream contents copyReplaceAll: String cr with: String lf.
	fs nextPutAll: results]
		ensure: [fs close].
	Transcript show: 'tests results have been saved in a file named ''' , resultsFileName , ''''; cr.
	^ results
]

{ #category : #'external system access' }
OSProcess class >> arguments [

	"OSProcess arguments"

	^ self thisOSProcess arguments

]

{ #category : #sUnit }
OSProcess class >> authorInitials [
	"Get the author initials from the system."

	((Smalltalk respondsTo: #metacelloPlatformAttributes)
		and: [ 
			(Smalltalk metacelloPlatformAttributes includes: #'pharo3.x')
				or: [ Smalltalk metacelloPlatformAttributes includes: #'pharo2.x' ] ])
		ifTrue: [ ^ (Smalltalk at: #Author) fullName select: [ :c | c isUppercase ] ].
	^ (Smalltalk at: #Utilities) authorInitials
]

{ #category : #private }
OSProcess class >> classForThisOSProcess [
	"Answer the class which represents the OS process in which Squeak runs."

	^ ThisOSProcess concreteClass
]

{ #category : #'external command processing' }
OSProcess class >> command: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in the standard C library,
	except that aCommandString runs asynchronously in a child process."

	"OSProcess command: 'ls -l /etc'"

	^ self thisOSProcess command: aCommandString

]

{ #category : #debugging }
OSProcess class >> debugMessage: aString [
	"Print aString on standard output. The debug message is prefixed with the
	identity of the process in which the method is being evaluated, and the
	identity of the object which received the message. Useful for debugging
	timing or deadlock problems."

	[self thisOSProcess stdOut
		"The process in which the traced message is being evaluated"
		nextPutAll: Processor activeProcess hash printString, ':';
		"The identity of the object being traced"
		nextPutAll: thisContext sender sender sender receiver hash printString, ':';
		"The debug message"
		nextPutAll: aString asString; nextPut: Character lf; flush]
			on: Error
			do: []
]

{ #category : #'version dependent' }
OSProcess class >> defaultPathString [

	^ self useFileSystem
		ifTrue: [(((Smalltalk at: #Path) perform: #workingDirectory) perform: #asFileReference) pathString]
		ifFalse: [(Smalltalk at: #FileDirectory) default pathName]

]

{ #category : #'version dependent' }
OSProcess class >> deleteFileNamed: fileName [
	"Delete the file with the given name."

	self useFileSystem
		ifTrue: [ | file |
			file := fileName perform: #asFileReference.
			( {	#ensureDelete "preferred selector" .
				#ensureDeleted "pharo 2, now deprecated in favor of ensureDelete" .
				#delete "fallback (earlier pharo versions?)" }
					detect: [ :e | file respondsTo: e ]
					ifNone: [ self error: 'do not know how to ensureDelete' ] )
				ifNotNilDo: [ :sel | file perform: sel ].
			(file respondsTo: #ensureDelete)
				ifTrue: [ file perform: #ensureDelete ]
				ifFalse: [ file perform: #ensureDeleted ] ]
		ifFalse: [ (Smalltalk at: #FileDirectory) default
				deleteFileNamed: fileName ]

]

{ #category : #'version dependent' }
OSProcess class >> directoryEntryNames: path [

	^ self useFileSystem
		ifTrue: [ (path perform: #asFileReference) children collect: [:e | e perform: #basename] ]
		ifFalse: [ ((Smalltalk at: #FileDirectory) on: path) entries collect: [:e | e name] ]

]

{ #category : #'version dependent' }
OSProcess class >> directoryExists: path [
	"Answer true if a directory of the given name exists. The given name may
	be either a full path name or a local directory within this directory."

	^ self useFileSystem
		ifTrue: [ (path perform: #asFileReference) exists ]
		ifFalse: [ (Smalltalk at: #FileDirectory) default directoryExists: path ]

]

{ #category : #'version dependent' }
OSProcess class >> fileExists: path [
	"Answer true if a file of the given name exists. The given name may be
	either a full path name or a local file within this directory."

	^ self useFileSystem
		ifTrue: [ (path perform: #asFileReference) exists ]
		ifFalse: [ (Smalltalk at: #FileDirectory) default fileExists: path ]

]

{ #category : #'version dependent' }
OSProcess class >> getSystemAttribute: attributeID [ 
	"After Squeak version 3.6, #getSystemAttribute was moved to SmalltalkImage "

	^ ((Smalltalk classNamed: 'SmalltalkImage')
		ifNil: [^ Smalltalk getSystemAttribute: attributeID]) current getSystemAttribute: attributeID
]

{ #category : #examples }
OSProcess class >> helloStdErr [
	"Write a message on the standard error stream of the OS process, normally
	the terminal or window from which Squeak is being run. Most operating
	systems implement stdin, stdout, and stderr in some manner, so this shown
	as an OSProcess example even though the implemention is in my subclasses."

	"OSProcess helloStdErr"

	| this |
	this := self thisOSProcess.
	this stdErr ifNil: [self noAccessorAvailable. ^ nil].
	^ this stdErr nextPutAll: 'Hello stderr'; nextPut: (Character lf); yourself
]

{ #category : #examples }
OSProcess class >> helloWorld [
	"Write a message on the standard output stream of the OS process, normally
	the terminal or window from which Squeak is being run. Most operating
	systems implement stdin, stdout, and stderr in some manner, so this shown
	as an OSProcess example even though the implemention is in my subclasses."

	"OSProcess helloWorld"

	| this |
	this := self thisOSProcess.
	this stdOut ifNil: [self noAccessorAvailable. ^ nil].
	^ this stdOut nextPutAll: 'Hello world'; nextPut: Character lf; yourself
]

{ #category : #'initialize-release' }
OSProcess class >> initialize [

	"OSProcess initialize"

	UseIOHandle := (Smalltalk hasClassNamed: #IOHandle)

]

{ #category : #'platform identification' }
OSProcess class >> isNonUnixMac [
	"True if the platform is Mac OS prior to OSX"

	"OSProcess isNonUnixMac"

	| numericOsVersion |
	numericOsVersion := self osVersion asInteger ifNil: [0].
	^ (self platformName = 'Mac OS') and: [numericOsVersion < 1000]

]

{ #category : #'platform identification' }
OSProcess class >> isOS2 [
	"True if the platform is OS2"
	"FIXME please - What is the correct platform name for OS2?"

	"OSProcess isOS2"

	^ self platformName = 'OS2'

]

{ #category : #'version dependent' }
OSProcess class >> isPharo3AndLater [
	"True if this image is a pharo of major version 3 or greater"

	Smalltalk
		at: #SystemVersion
		ifPresent: [:cls | ((cls canUnderstand: #type) and: [ cls canUnderstand: #major ])
			ifTrue: [^ cls current type = 'Pharo' and: [ cls current major >= 3 ]]].
	^false

]

{ #category : #'platform identification' }
OSProcess class >> isResponsibleForThisPlatform [
	"Answer true if this class has responsibilities for the platform on which the
	Squeak VM is currently running."

	^ self subclassResponsibility
]

{ #category : #'platform identification' }
OSProcess class >> isRiscOS [
	"True if the platform is RiscOS"

	"OSProcess isRiscOS"

	^ self platformName = 'RiscOS'
]

{ #category : #'platform identification' }
OSProcess class >> isUnix [
	"True if the platform is Unix (including Linux, Mac OS X, or other unix-like OS).
	Note: Keep this method in sync with UnixOSProcessPlugin>>isResponsibleForThisPlatform."

	"OSProcess isUnix"

	| numericOsVersion |

	^ (self platformName = 'unix') or:
		[numericOsVersion := self osVersion asInteger ifNil: [0].
		(self platformName = 'Mac OS') and: [numericOsVersion >= 1000]]

]

{ #category : #'platform identification' }
OSProcess class >> isUnixMac [
	"True if the platform is Mac OS on OSX"

	"OSProcess isUnixMac"

	| osVersion numericOsVersion |
	osVersion := self osVersion.
	^ ('darwin*' match: osVersion "Ian's VM")
		or: [numericOsVersion := osVersion asInteger ifNil: [0].
			(self platformName = 'Mac OS') and: [numericOsVersion >= 1000] "John's VM"]

]

{ #category : #'platform identification' }
OSProcess class >> isWindows [
	"True if the platform is an MS Windows OS"

	"OSProcess isWindows"

	^ self platformName = 'Win32'
]

{ #category : #'version dependent' }
OSProcess class >> listLoadedModules [
	"After Squeak version 3.6, #listLoadedModules was moved to SmalltalkImage "

	^ ((Smalltalk classNamed: 'SmalltalkImage')
		ifNil: [^ Smalltalk listLoadedModules]) current listLoadedModules
]

{ #category : #utility }
OSProcess class >> makeVM [
	"Rebuild the virtual machine and plugins, assuming that this Squeak
	is running from a home directory in the appropriate place in the
	source code tree. If the build is successful, save the image and
	restart using the new VM."

	"OSProcess makeVM"

	^ self makeVmIn: OSProcess defaultPathString, OSProcess pathSeparator, 'build'

]

{ #category : #utility }
OSProcess class >> makeVmIn: buildDirectoryPathName [
	"Rebuild the virtual machine and plugins in the buildDirectoryPathName
	directory. If the build is successful, save the image and restart using the
	new VM. This assumes that the currently executing VM is either located in,
	or linked to, the buildDirectoryPathName directory."

	"OSProcess makeVmIn: OSProcess defaultPathString, OSProcess pathSeparator, 'build'"

	^ self classForThisOSProcess makeVmIn: buildDirectoryPathName


]

{ #category : #private }
OSProcess class >> noAccessorAvailable [

	self notify: 'process accessor module not available'
]

{ #category : #'version dependent' }
OSProcess class >> osVersion [
	"After Squeak version 3.6, #osVersion was moved to SmalltalkImage. Some
	versions of Pharo move this to OSPlatform and issue deprecation warnings
	about the other usages. Pharo3 deprecated OSPlatform direct access."

	"self osVersion"
	
	self isPharo3AndLater
		ifTrue: [ ^ (Smalltalk perform: #os) version ].
	^ (((Smalltalk hasClassNamed: #OSPlatform)
			and: [(Smalltalk at: #OSPlatform)
					respondsTo: #osVersion])
		ifTrue: [Smalltalk at: #OSPlatform]
		ifFalse: [((Smalltalk classNamed: 'SmalltalkImage')
				ifNil: [^ Smalltalk osVersion]) current]) osVersion
]

{ #category : #'version dependent' }
OSProcess class >> pathSeparator [

	^ self useFileSystem
		ifTrue: [((Smalltalk at: #DiskStore) current perform: #delimiter) asString]
		ifFalse: [(Smalltalk at: #FileDirectory) slash]

]

{ #category : #'version dependent' }
OSProcess class >> platformName [ 
	"After Squeak version 3.6, #platformName was moved to SmalltalkImage Some
	versions of Pharo move this to OSPlatform and issue deprecation warnings
	about the other usages. The original idiom (Squeak 3.6 and earlier) is the sensible
	default, but here we attempt to support other implementations if the sensible
	default is not available."

	"OSProcess platformName"

	(Smalltalk respondsTo: #platformName)
		ifTrue: [^ Smalltalk platformName].
	self isPharo3AndLater
		ifTrue: [ ^ (Smalltalk perform: #os) name ].
	^ (((Smalltalk hasClassNamed: #OSPlatform)
			and: [(Smalltalk at: #OSPlatform)
					respondsTo: #platformName])
		ifTrue: [Smalltalk at: #OSPlatform]
		ifFalse: [((Smalltalk classNamed: 'SmalltalkImage')
				ifNil: [^ Smalltalk osVersion]) current]) platformName
]

{ #category : #'version dependent' }
OSProcess class >> platformSubtype [ 
	"After Squeak version 3.6, #platformSubtype was moved to SmalltalkImage "

	"OSProcess platformSubtype"

	self isPharo3AndLater
		ifTrue: [ ^ (Smalltalk perform: #os) perform: #subtype ].
	^ ((Smalltalk classNamed: 'SmalltalkImage')
		ifNil: [^ Smalltalk platformSubtype]) current platformSubtype
]

{ #category : #'external system access' }
OSProcess class >> programName [

	"OSProcess programName"

	^ self thisOSProcess programName

]

{ #category : #utility }
OSProcess class >> quitAndRestart [
	"Save image, start a new instance from the saved image, and quit this instance.
	This is useful if the VM has been recompiled or if a new pluggable primitive
	has been added."

	"OSProcess quitAndRestart"

	| firstPid this |
	firstPid := OSProcess thisOSProcess pid.
	firstPid ifNil: 
			[self noAccessorAvailable.
			^ nil].
	Smalltalk saveSession.
	"Value of firstPid gets saved in the image"
	this := OSProcess thisOSProcess.
	this pid = firstPid ifTrue: [self squeak ifNotNil: [Smalltalk quitPrimitive]].
	^ this
]

{ #category : #examples }
OSProcess class >> readFromStdIn [
	"Type some text on the standard input terminal, followed by <return> or <enter>,
	then call this method. Any available input text in the stdin stream will be read.
	This method sets standard input for the Squeak OS process for non-blocking reads
	in order to prevent the Smalltalk image from blocking on the read. After the read,
	standard input is set back to its normal blocking I/O mode.

	Most operating systems implement stdin, stdout, and stderr in some manner, so this
	is shown as an OSProcess example even though the implemention is in my subclasses."

	"OSProcess readFromStdIn inspect"

	| input ioHandle resultString |
	input := self thisOSProcess stdIn.
	input ifNil: [self noAccessorAvailable. ^ nil].
	ioHandle := input ioHandle.
	self accessor setNonBlocking: ioHandle.
	resultString := self thisOSProcess stdIn next: 10000.
	self accessor setBlocking: ioHandle.
	^ resultString

]

{ #category : #'version dependent' }
OSProcess class >> snapshot: save andQuit: quit [
	"After Squeak version 3.6, #snapshot:andQuit: was moved to SmalltalkImage "

	^ ((Smalltalk classNamed: 'SmalltalkImage')
		ifNil: [^ Smalltalk snapshot: save andQuit: quit embedded: false]) current snapshot: save andQuit: quit
]

{ #category : #'external command processing' }
OSProcess class >> squeak [
	"Start a new instance of Squeak running in a child OS process. The new instance
	will restart from the image file, so it is a clone of this image as it existed at the
	most recent image save. Note that subclasses can implement additional methods of
	starting Squeak images, especially for Unix systems."

	"OSProcess squeak"

	^ self thisOSProcess squeak


]

{ #category : #utility }
OSProcess class >> systemAttributes [
	"Answer a Dictionary of all of the system attributes which can be obtained from
	SystemDictionary>>getSystemAttribute."

	"OSProcess systemAttributes"

	| args idx a |
	args := Dictionary new.

	idx := -1.
	[a := self getSystemAttribute: idx.
	a notNil and: [a size > 0]]
		whileTrue: [args at: idx put: a. idx := idx - 1].

	a := self getSystemAttribute: 0.
	(a notNil and: [a size > 0]) ifTrue: [args at: 0 put: a. idx := idx - 1].
	a := self getSystemAttribute: 1.
	(a notNil and: [a size > 0]) ifTrue: [args at: 1 put: a. idx := idx - 1].
	a := self getSystemAttribute: 2.
	(a notNil and: [a size > 0]) ifTrue: [args at: 2 put: a. idx := idx - 1].

	idx := 2.
	[a := self getSystemAttribute: idx.
	a notNil and: [a size > 0]]
		whileTrue: [args at: idx put: a. idx := idx + 1].

	idx := 1001.
	[a := self getSystemAttribute: idx.
	a notNil and: [a size > 0]]
		whileTrue: [args at: idx put: a. idx := idx + 1].

	^ args.


]

{ #category : #'instance creation' }
OSProcess class >> thisOSProcess [
	"Answer the single instance of the class corresponding to the OS process in which
	this Smalltalk image is executing."

	"OSProcess thisOSProcess"

	^ ThisOSProcess thisOSProcess

]

{ #category : #debugging }
OSProcess class >> trace [
	"Print the sender's context on standard output. The debug message is
	prefixed with the identity of the process in which the method is being
	evaluated, and the identity of the object which received the message.
	Useful for debugging timing or deadlock problems."

	[self thisOSProcess stdOut
		"The process in which the traced message is being evaluated"
		nextPutAll: Processor activeProcess hash printString, ':';
		"The identity of the object being traced"
		nextPutAll: thisContext sender sender sender receiver hash printString, ':';
		"The method context describing the method being evaluated"
		nextPutAll: thisContext sender sender sender printString;
		nextPut: Character lf;
		flush]
			on: Error
			do: []
]

{ #category : #debugging }
OSProcess class >> trace: debugMessageString [
	"Print trace information followed by a debug message"

	[self thisOSProcess stdOut
		"The process in which the traced message is being evaluated"
		nextPutAll: Processor activeProcess hash printString, ':';
		"The identity of the object being traced"
		nextPutAll: thisContext sender sender sender receiver hash printString, ':';
		"The method context describing the method being evaluated"
		nextPutAll: thisContext sender sender sender printString, ':';
		nextPutAll: debugMessageString;
		nextPut: Character lf;
		flush]
			on: Error
			do: []
]

{ #category : #'version dependent' }
OSProcess class >> useFileSystem [
	"If true use FileSystem, otherwise use traditional FileDirectory. See senders
	for methods with file system dependencies."

	^ Smalltalk hasClassNamed: #FileReference
]

{ #category : #'version testing' }
OSProcess class >> versionInformation [

	"OSProcess versionInformation"

	| osppVersion |
	osppVersion := (Smalltalk hasClassNamed: #OSProcessPlugin)
		ifTrue:
			[(Smalltalk at: #OSProcessPlugin) versionInformation]
		ifFalse:
			['(not installed in this image)'].
	^ Array
		with: (self name, ' version ', self versionString)
		with: ((Smalltalk hasClassNamed: #CommandShell)
				ifTrue:
					[((Smalltalk at: #CommandShell) respondsTo: #versionString)
						ifTrue:
							['CommandShell version ', (Smalltalk at: #CommandShell) versionString]
						ifFalse:
							['CommandShell installed (old version, no versionString)']]
				ifFalse:
					['CommandShell is not installed'])
		with:  osppVersion

]

{ #category : #'version testing' }
OSProcess class >> versionString [

	"OSProcess versionString"

	^'4.5.11'
]

{ #category : #'version dependent' }
OSProcess class >> vmVersion [ 
	"After Squeak version 3.6, #vmVersion was moved to SmalltalkImage. Pharo3 deprecated vmVersion."

	self isPharo3AndLater
		ifTrue: [ ^ (Smalltalk perform: #vm) version ].
	^ ((Smalltalk classNamed: 'SmalltalkImage')
		ifNil: [^ Smalltalk vmVersion]) current vmVersion
]

{ #category : #'external command processing' }
OSProcess class >> waitForCommand: aCommandString [
	"Run a command in a shell process. Similar to the system(3) call in the standard C library.
	The active Smalltalk process waits for completion of the external command process."

	"OSProcess waitForCommand: 'echo sleeping...; sleep 3; echo I just slept for three seconds'"

	^ self thisOSProcess waitForCommand: aCommandString

]

{ #category : #'initialize - release' }
OSProcess >> initialize [

	self subclassResponsibility
]

{ #category : #testing }
OSProcess >> isExternalProcess [

	^ true
]

{ #category : #private }
OSProcess >> noAccessorAvailable [

	^ self class noAccessorAvailable

]

{ #category : #accessing }
OSProcess >> pid [

	^ pid

]

{ #category : #accessing }
OSProcess >> pid: processIdentifier [

	pid := processIdentifier

]

{ #category : #printing }
OSProcess >> printOn: aStream [

	super printOn: aStream. aStream nextPutAll: ' with pid '. self pid printOn: aStream
]
