"
Unit tests for the Unix portion of OSProcess.
"
Class {
	#name : #UnixProcessTestCase,
	#superclass : #TestCase,
	#instVars : [
		'thisOSProcess'
	],
	#category : #'OSProcess-Tests'
}

{ #category : #failures }
UnixProcessTestCase class >> expectedFailures [
	^UnixOSProcessAccessor basicNew safeToForkSqueak
		ifTrue: [#()]
		ifFalse: [#(	testClassForkHeadlessSqueakAndDo
					testClassForkHeadlessSqueakAndDoThenQuit
					testClassForkSqueak
					testClassForkSqueakAndDo
					testClassForkSqueakAndDoThenQuit
					testForkHeadlessSqueakAndDo
					testForkHeadlessSqueakAndDoThenQuit
					testForkSqueak
					testForkSqueakAndDo
					testForkSqueakAndDoThenQuit
					testHeadlessChild
					testSpawnTenHeadlessChildren)]
]

{ #category : #failures }
UnixProcessTestCase >> expectedFailures [
	^UnixOSProcessAccessor basicNew safeToForkSqueak
		ifTrue: [#()]
		ifFalse: [#(	testClassForkHeadlessSqueakAndDo
					testClassForkHeadlessSqueakAndDoThenQuit
					testClassForkSqueak
					testClassForkSqueakAndDo
					testClassForkSqueakAndDoThenQuit
					testEightLeafSqueakTree
					testForkHeadlessSqueakAndDo
					testForkHeadlessSqueakAndDoThenQuit
					testForkSqueak
					testForkSqueakAndDo
					testForkSqueakAndDoThenQuit
					testHeadlessChild
					testSpawnTenHeadlessChildren)]
]

{ #category : #private }
UnixProcessTestCase >> numberOfOpenFiles [
	"Answer the number of files currently open for this OS process. This works
	only on a system with a /proc filesystem and file descriptors located in a
	directory called /proc/<pid>/fd. On other systems, just answer 0."

	"UnixProcessTestCase new numberOfOpenFiles"

	| path |
	path := '/proc/' , OSProcess thisOSProcess pid printString, '/fd'.
	^ (OSProcess directoryExists: path)
		ifTrue: [(OSProcess directoryEntryNames: path) size]
		ifFalse: [0]

]

{ #category : #running }
UnixProcessTestCase >> runAll [
	"If you get intermittent failures, try doing a garbage collect. Some of these
	tests can fail intermittently on the open file handle count checks"

	"UnixProcessTestCase new runAll"

	| result suite |
	Smalltalk garbageCollect.
	suite := TestSuite new.
	suite addTest: (UnixProcessTestCase selector: #testClassForkSqueak).
	suite addTest: (UnixProcessTestCase selector: #testClassForkSqueakAndDo).
	suite addTest: (UnixProcessTestCase selector: #testClassForkSqueakAndDoThenQuit).
	suite addTest: (UnixProcessTestCase selector: #testClassForkHeadlessSqueakAndDo).
	suite addTest: (UnixProcessTestCase selector: #testClassForkHeadlessSqueakAndDoThenQuit).
	suite addTest: (UnixProcessTestCase selector: #testForkSqueak).
	suite addTest: (UnixProcessTestCase selector: #testForkSqueakAndDo).
	suite addTest: (UnixProcessTestCase selector: #testForkSqueakAndDoThenQuit).
	suite addTest: (UnixProcessTestCase selector: #testForkHeadlessSqueakAndDo).
	suite addTest: (UnixProcessTestCase selector: #testForkHeadlessSqueakAndDoThenQuit).
	suite addTest: (UnixProcessTestCase selector: #testHeadlessChild).
	suite addTest: (UnixProcessTestCase selector: #testSpawnTenHeadlessChildren).
	suite addTest: (UnixProcessTestCase selector: #testEightLeafSqueakTree).
	suite addTest: (UnixProcessTestCase selector: #testCatAFile).
	suite addTest: (UnixProcessTestCase selector: #testCatFromFileToFiles).
	suite addTest: (UnixProcessTestCase selector: #testRunCommand).
	suite addTest: (UnixProcessTestCase selector: #testPipe).
	suite addTest: (UnixProcessTestCase selector: #testPipeLine).

	result := suite run.
	self should: [result defects size == 0].
	^ result

]

{ #category : #running }
UnixProcessTestCase >> setUp [

	(self respondsTo: #timeout: ) "Recent Squeak images with test case timeout"
		ifTrue: [self perform: #timeout: with: 60].
	thisOSProcess := OSProcess thisOSProcess

]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testCatAFile [

	"(UnixProcessTestCase selector: #testCatAFile) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt: [p := UnixProcess catAFile]
		raise: Warning.
	self assert: p notNil.
	self should: [p isRunning].
	[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
	self should: [p isComplete].
	self should: [p exitStatus == 0].
	self should: [p initialStdIn closed]. "Used a file for input, should be closed"
	self shouldnt: [p initialStdOut closed]. "Shared stdout with the VM, should be open"
	self shouldnt: [p initialStdErr closed]. "Shared stderr with the VM, should be open"
	self assert: self numberOfOpenFiles == openFileCount

]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testCatFromFileToFiles [

	"(UnixProcessTestCase selector: #testCatFromFileToFiles) run"

	| p f openFileCount |
	openFileCount := self numberOfOpenFiles.
	OSProcess deleteFileNamed: '/tmp/deleteMe.out'.
	OSProcess deleteFileNamed: '/tmp/deleteMe.err'.
	self shouldnt: [p := UnixProcess catFromFileToFiles]
		raise: Warning.
	self assert: p notNil.
	self should: [p isRunning].
	[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
	self should: [p isComplete].
	self should: [p exitStatus == 0].
	self should: [p initialStdIn closed].
	self should: [p initialStdOut closed].
	self should: [p initialStdErr closed].
	f := FileStream oldFileNamed: '/tmp/deleteMe.out'.
	self shouldnt: [f upToEnd isEmpty].
	f close.
	f := FileStream oldFileNamed: '/tmp/deleteMe.err'.
	self should: [f upToEnd isEmpty].
	f close.
	self assert: self numberOfOpenFiles == openFileCount

]

{ #category : #'testing - class side methods' }
UnixProcessTestCase >> testClassForkHeadlessSqueakAndDo [

	"(UnixProcessTestCase selector: #testClassForkHeadlessSqueakAndDo) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
		[p := UnixProcess forkHeadlessSqueakAndDo:
			[(Delay forMilliseconds: 100) wait.
			OSProcess snapshot: false andQuit: true]]
		raise: Warning. "Catch warning if fork fails"
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - class side methods' }
UnixProcessTestCase >> testClassForkHeadlessSqueakAndDoThenQuit [

	"(UnixProcessTestCase selector: #testClassForkHeadlessSqueakAndDoThenQuit) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
		[p := UnixProcess forkHeadlessSqueakAndDoThenQuit:
			[(Delay forMilliseconds: 100) wait]]
		raise: Warning. "Catch warning if fork fails"
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - class side methods' }
UnixProcessTestCase >> testClassForkSqueak [

	"(UnixProcessTestCase selector: #testClassForkSqueak) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt: [p := UnixProcess forkSqueak]
		raise: Warning.
	self assert: p notNil.
	(p == thisOSProcess)
		ifTrue:
			["Child Squeak"
			p inspect.
			(Delay forMilliseconds: 100) wait.
			OSProcess snapshot: false andQuit: true]
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - class side methods' }
UnixProcessTestCase >> testClassForkSqueakAndDo [

	"(UnixProcessTestCase selector: #testClassForkSqueakAndDo) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
			[p := UnixProcess forkSqueakAndDo:
					[(Delay forMilliseconds: 100) wait.
					OSProcess snapshot: false andQuit: true]]
		raise: Warning.
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - class side methods' }
UnixProcessTestCase >> testClassForkSqueakAndDoThenQuit [

	"(UnixProcessTestCase selector: #testClassForkSqueakAndDoThenQuit) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
			[p := UnixProcess forkSqueakAndDoThenQuit:
					[(Delay forMilliseconds: 100) wait]]
		raise: Warning.
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testEightLeafSqueakTree [

	"(UnixProcessTestCase selector: #testEightLeafSqueakTree) run"

	| a openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt: [a := UnixProcess eightLeafSqueakTree]
		raise: Warning.
	self assert: (a isKindOf: Array).
	self assert: a size == 3.
	(a includes: 0)
		ifTrue:
			[Smalltalk quitPrimitive].
	self assert: self numberOfOpenFiles == openFileCount

]

{ #category : #'testing - child process creation' }
UnixProcessTestCase >> testForkHeadlessSqueakAndDo [

	"(UnixProcessTestCase selector: #testForkHeadlessSqueakAndDo) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
			[p := thisOSProcess forkHeadlessSqueakAndDo:
					[(Delay forMilliseconds: 100) wait.
					OSProcess snapshot: false andQuit: true]]
		raise: Warning. "Catch warning if fork fails"
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - child process creation' }
UnixProcessTestCase >> testForkHeadlessSqueakAndDoThenQuit [

	"(UnixProcessTestCase selector: #testForkHeadlessSqueakAndDoThenQuit) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
			[p := thisOSProcess forkHeadlessSqueakAndDoThenQuit:
					[(Delay forMilliseconds: 100) wait]]
		raise: Warning. "Catch warning if fork fails"
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - child process creation' }
UnixProcessTestCase >> testForkSqueak [

	"(UnixProcessTestCase selector: #testForkSqueak) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt: [p := thisOSProcess forkSqueak]
		raise: Warning. "Catch warning if fork fails"
	self assert: p notNil.
	(p == thisOSProcess)
		ifTrue:
			["Child Squeak"
			p inspect.
			(Delay forMilliseconds: 100) wait.
			OSProcess snapshot: false andQuit: true]
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - child process creation' }
UnixProcessTestCase >> testForkSqueakAndDo [

	"(UnixProcessTestCase selector: #testForkSqueakAndDo) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
			[p := thisOSProcess forkSqueakAndDo:
					[(Delay forMilliseconds: 100) wait.
					OSProcess snapshot: false andQuit: true]]
		raise: Warning.
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - child process creation' }
UnixProcessTestCase >> testForkSqueakAndDoThenQuit [

	"(UnixProcessTestCase selector: #testForkSqueakAndDoThenQuit) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt:
			[p := thisOSProcess forkSqueakAndDoThenQuit:
					[(Delay forMilliseconds: 100) wait]]
		raise: Warning.
	self assert: p notNil.
	(p == thisOSProcess)
		ifFalse:
			["Parent Squeak process"
			self should: [p isRunning].
			[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
			self should: [p isComplete].
			self should: [p exitStatus == 0].
			self assert: self numberOfOpenFiles == openFileCount]

]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testHeadlessChild [

	"(UnixProcessTestCase selector: #testHeadlessChild) run"

	| p openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt: [p := UnixProcess headlessChild]
		raise: Warning. "Catch warning if fork fails"
	[p isComplete] whileFalse: [(Delay forMilliseconds: 100) wait].
	self assert: p isComplete.
	self assert: p exitStatus == 0.
	self assert: self numberOfOpenFiles == openFileCount

]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testPipe [

	"(UnixProcessTestCase selector: #testPipe) run"

	| openFileCount |
	openFileCount := self numberOfOpenFiles.
	self should: [UnixProcess testPipe = 'this is some text to write into the pipe'].
	self assert: self numberOfOpenFiles == openFileCount

]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testPipeLine [

	"(UnixProcessTestCase selector: #testPipeLine) run"

	| openFileCount |
	openFileCount := self numberOfOpenFiles.
	self should: ['This is the text to write*' match: UnixProcess testPipeLine].
	self assert: self numberOfOpenFiles == openFileCount

]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testRunCommand [

	"(UnixProcessTestCase selector: #testRunCommand) run"

	| p f openFileCount |
	openFileCount := self numberOfOpenFiles.
	OSProcess deleteFileNamed: '/tmp/deleteMe.out'.
	OSProcess deleteFileNamed: '/tmp/deleteMe.err'.
	self shouldnt: [p := UnixProcess testRunCommand]
		raise: Warning.
	self assert: p notNil.
	self should: [p isRunning].
	[p isRunning] whileTrue: [(Delay forMilliseconds: 100) wait].
	self should: [p isComplete].
	self should: [p exitStatus > 0].	"Forced an error exit status"
	"stdin was shared with the Squeak VM, so it should not have been closed."
	self shouldnt: [p initialStdIn closed].
	"but the output and error streams should have been closed."
	self should: [p initialStdOut closed].
	self should: [p initialStdErr closed].
	f := FileStream oldFileNamed: '/tmp/deleteMe.out'.
	self shouldnt: [f upToEnd isEmpty].
	f close.
	f := FileStream oldFileNamed: '/tmp/deleteMe.err'.
	self shouldnt: [f upToEnd isEmpty].
	f close.
	self assert: self numberOfOpenFiles == openFileCount



]

{ #category : #'testing - class examples' }
UnixProcessTestCase >> testSpawnTenHeadlessChildren [

	"(UnixProcessTestCase selector: #testSpawnTenHeadlessChildren) run"

	| a openFileCount |
	openFileCount := self numberOfOpenFiles.
	self shouldnt: [a := UnixProcess spawnTenHeadlessChildren]
		raise: Warning. "Catch warning if fork fails"
	[(a detect: [:p | p isComplete not] ifNone: []) notNil]
		whileTrue: [(Delay forMilliseconds: 100) wait].
	self should: [(a select: [:p | p isComplete not]) isEmpty].
	self assert: self numberOfOpenFiles == openFileCount

]
