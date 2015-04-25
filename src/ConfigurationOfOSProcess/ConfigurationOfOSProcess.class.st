"
OSProcess provides access to operating system functions, including pipes and child process creation. It is implemented using pluggable primitives in a shared library for Unix or Linux, and a DLL for Windows. The Smalltalk code, including the classes which implement pluggable primitives for Unix or Win32 operating system functions, may be loaded into any Squeak image, but the primitives are only useful on Unix and Windows systems. Placeholder classes are provided for MacOS, OS/2 and RiscOS, but are not yet implemented.

ConfigurationOfOSProcess project stableVersion load.
"
Class {
	#name : #ConfigurationOfOSProcess,
	#superclass : #Object,
	#instVars : [
		'project'
	],
	#classVars : [
		'LastVersionLoad'
	],
	#category : #ConfigurationOfOSProcess
}

{ #category : #private }
ConfigurationOfOSProcess class >> bootstrapPackage: aString from: aPath [ 
	| repository version |
	repository := MCHttpRepository
				location: aPath
				user: ''
				password: ''.
	repository
		versionReaderForFileNamed: aString , '.mcz'
		do: [:reader | 
			version := reader version.
			version load.
			version workingCopy repositoryGroup addRepository: repository]
]

{ #category : #private }
ConfigurationOfOSProcess class >> ensureMetacello [
	"Bootstrap Gofer (if necessary), bootstrap ConfigurationOfMetacello (using old Gofer API), then load the latest 
	version of Metacello itself."

	Smalltalk at: #MetacelloProject ifAbsent: [
		Smalltalk at: #Gofer ifAbsent: [
			"Current version of Gofer from which to bootstrap - as of 1.0-beta.15"
			self bootstrapPackage: 'Gofer-lr.83' from: 'http://seaside.gemstone.com/ss/metacello' ].
		Smalltalk at: #Gofer ifPresent: [:goferClass | | gofer |
			gofer := goferClass new
				url: 'http://seaside.gemstone.com/ss/metacello';
				yourself.
			[ gofer addPackage: 'ConfigurationOfMetacello' ] on: Warning do: [:ex | ex resume ].
			gofer load ].
		"load 'default' group of Metacello"
		(Smalltalk at: #ConfigurationOfMetacello) perform: #load ]
]

{ #category : #'metacello tool support' }
ConfigurationOfOSProcess class >> isMetacelloConfig [
	"Answer true and the Metacello tools will operate on you"
	
	^true
]

{ #category : #'metacello tool support' }
ConfigurationOfOSProcess class >> lastMetacelloVersionLoad [
	"Answer the last version loaded and the list of packages loaded for that version."

	LastVersionLoad == nil ifTrue: [ LastVersionLoad := nil -> 'default' ].
	^LastVersionLoad
]

{ #category : #loading }
ConfigurationOfOSProcess class >> load [
	"self load"

	| r |
	r := self project latestVersion load.
	(Smalltalk at: #ThisOSProcess) ifNotNilDo: [ :osp | osp startUp: true ] "initialize"
]

{ #category : #'metacello tool support' }
ConfigurationOfOSProcess class >> metacelloVersion: versionString loads: anArrayOrString [
	"Stash the last version loaded and the list of packages loaded for that version. The list
	 of packages will be used by the tools when doing 'Load Package Version'"

	LastVersionLoad := versionString -> anArrayOrString
]

{ #category : #accessing }
ConfigurationOfOSProcess class >> project [

	^self new project
]

{ #category : #baselines }
ConfigurationOfOSProcess >> baseline4312: spec [
	<version: '4.3.12-baseline'>
	
	spec for: #common do: [
		spec blessing: #baseline.
		spec description: 'Initial baseline for OSProcess'.
		spec repository: 'http://www.squeaksource.com/OSProcess' ].
	
	spec for: #squeakCommon do: [
		spec
			repository: 'http://www.squeaksource.com/OSProcess';
			package: 'OSProcess-Base';
   			package: 'OSProcess-AIO' with: [ spec requires: 'OSProcess-Base' ];
  			package: 'OSProcess-Mac' with: [ spec requires: 'OSProcess-Base' ];
  			package: 'OSProcess-OS2' with: [ spec requires: 'OSProcess-Base' ];
  			package: 'OSProcess-RiscOS' with: [ spec requires: 'OSProcess-Base' ];
  			package: 'OSProcess-Unix' with: [ spec requires: 'OSProcess-Base' ];
  			package: 'OSProcess-Win32' with: [ spec requires: 'OSProcess-Base' ];
  			package: 'OSProcess-Tests' with: [ spec requires: 'OSProcess-Base' ] ].
	
	spec for: #common do: [
		spec
			group: 'default' with: #('OSProcess' 'OSProcess-AIO' 'Tests');
			group: 'OSProcess' with: #('OSProcess-Base' 'Platforms');
			group: 'Platforms' with: 'OSProcess-Mac';
			group: 'Platforms' with: 'OSProcess-OS2';
			group: 'Platforms' with: 'OSProcess-RiscOS';
			group: 'Platforms' with: 'OSProcess-Unix';
			group: 'Platforms' with: 'OSProcess-Win32';
			group: 'Tests' with: 'OSProcess-Tests' ].
]

{ #category : #baselines }
ConfigurationOfOSProcess >> baseline43: spec [
	<version: '4.3-baseline'>
	
	spec for: #common do: [
		spec blessing: #baseline.
		spec description: 'Initial baseline for OSProcess'.
		spec repository: 'http://www.squeaksource.com/OSProcess' ].
	
	spec for: #squeakCommon do: [
		spec
			repository: 'http://www.squeaksource.com/OSProcess';
			package: 'OSProcess';
  			package: 'Tests-OSProcess' with: [ spec requires: 'OSProcess' ] ].
	
	spec for: #common do: [
		spec
			group: 'default' with: 'OSProcess';
			group: 'Tests' with: 'Tests-OSProcess' ].
]

{ #category : #baselines }
ConfigurationOfOSProcess >> baseline446: spec [
	<version: '4.4.6-baseline'>

	spec for: #'common' do: [
		spec blessing: #'baseline'.
		spec description: 'Load the OSProcess-* packages instead of the OSProcess all-in-one package.

David Lewis has said that these packages will be kept in sync with the al-in-one and this will give us greater flexibility in what to load.

For example, we can now optionally load the tests. This seemed possible with the previous version, but actually the tests were always loaded as part of the all-in-one'.
		spec repository: 'http://www.squeaksource.com/OSProcess'.
		spec project: 'Pipeability' with: [
			spec
				repository: 'http://www.squeaksource.com/MetacelloRepository';
				className: 'ConfigurationOfCommandShell';
				loads: #('Piping') ].
		spec 
			package: 'OSProcess-AIO';
			package: 'OSProcess-Base' with: [ spec requires: #('OSProcess-AIO') ];
			package: 'OSProcess-OS2' with: [ spec requires: #('OSProcess-Base') ];
			package: 'OSProcess-Win32' with: [ spec requires: #('OSProcess-Base') ];
			package: 'OSProcess-Unix' with: [ spec requires: #('OSProcess-Base') ];
			package: 'OSProcess-Mac' with: [ spec requires: #('OSProcess-Base') ];
			package: 'OSProcess-RiscOS' with: [ spec requires: #('OSProcess-Base') ];
			package: 'OSProcess-Tests' with: [ spec requires: #('OSProcess-Base') ].
		spec
			group: 'All OS' with: #('OSProcess-OS2' 'OSProcess-Win32' 'OSProcess-Unix' 'OSProcess-Mac' 'OSProcess-RiscOS');
			group: 'Core' with: #('OSProcess-AIO' 'OSProcess-Base' 'All OS');
			group: 'Core with Output' with: #('Core' 'Pipeability');
			group: 'Tests' with: #('OSProcess-Tests' ). ].

]

{ #category : #baselines }
ConfigurationOfOSProcess >> baseline44: spec [
	<version: '4.4-baseline'>

	spec for: #'common' do: [
		spec blessing: #'baseline'.
		spec repository: 'http://www.squeaksource.com/OSProcess'.
		spec 
			package: 'OSProcess';
			package: 'OSProcess-Tests' with: [
				spec requires: #('OSProcess' ). ].
		spec 
			group: 'default' with: #('OSProcess' );
			group: 'Tests' with: #('OSProcess-Tests' ). ].

]

{ #category : #private }
ConfigurationOfOSProcess >> loadType [

	self flag: 'OSProcess''s packages are highly interdependent (some circular), so we must load atomically for now. After these issues are resolved, this can be shanged to #linear'.
	^ #atomic.
]

{ #category : #accessing }
ConfigurationOfOSProcess >> project [

	^ project ifNil: [ | constructor |
		"Bootstrap Metacello if it is not already loaded"
		self class ensureMetacello.
		"Construct Metacello project"
		constructor := (Smalltalk at: #MetacelloVersionConstructor) on: self.
		project := constructor project.
		project loadType: self loadType.
		project ]
]

{ #category : #'symbolic versions' }
ConfigurationOfOSProcess >> stable: spec [
	<symbolicVersion: #'stable'>

	spec for: #'common' version: '4.6.2'.
	spec for: #'pharo1.4.x' version: '4.4.6'.
	spec for: #'pharo2.x' version: '4.5.8'.
]

{ #category : #versions }
ConfigurationOfOSProcess >> version4311: spec [
	<version: '4.3.11' imports: #('4.3-baseline')>
	
	spec for: #common do: [
		spec blessing: #development.
		spec description: 'Release 4.3.11'.
		spec author: 'MiguelCoba'.
		spec timestamp: '01/14/2010 00:30' ].
	
	spec for: #squeakCommon do: [
		spec
		  	package: 'OSProcess' with: 'OSProcess-dtl.53';
			package: 'Tests-OSProcess' with: 'Tests-OSProcess-dtl.20' ].
]

{ #category : #versions }
ConfigurationOfOSProcess >> version4312: spec [
	<version: '4.3.12' imports: #('4.3.12-baseline')>
	
	spec for: #common do: [
		spec blessing: #development.
		spec description: 'Release 4.3.12'.
		spec author: 'dtl'.
		spec timestamp: '06/30/2010 19:55' ].
	
	spec for: #squeakCommon do: [
		spec
		  	package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.4';
		  	package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.1';
		  	package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.1';
		  	package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.1';
		  	package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.1';
		  	package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.3';
		  	package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.2';
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.1' ].
]

{ #category : #versions }
ConfigurationOfOSProcess >> version440: spec [
	<version: '4.4.0' imports: #('4.4-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Version 4.4.0'.
		spec author: 'MiguelCoba'.
		spec timestamp: '2/19/2011 01:59'.
		spec 
			package: 'OSProcess' with: 'OSProcess-dtl.59';
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.4'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version442: spec [
	<version: '4.4.2' imports: #('4.4-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Version 4.4.2'.
		spec author: 'MiguelCoba'.
		spec timestamp: '5/29/2011 12:34'.
		spec 
			package: 'OSProcess' with: 'OSProcess-dtl.61';
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.4'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version445: spec [
	<version: '4.4.5' imports: #('4.4-baseline' )>

	spec for: #'common' do: [
		spec blessing: #release.
		spec description: 'Version 4.4.5'.
		spec author: 'Marcel Taeumel'.
		spec timestamp: '9/28/2011 14:00'.
		spec 
			package: 'OSProcess' with: 'OSProcess-dtl.65';
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.7'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version446: spec [
	<version: '4.4.6' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'SeanDeNigris'.
		spec timestamp: '7/5/2012 12:57'.
		spec project: 'Pipeability' with: [ spec version: '1.0' ].
		spec 
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.9';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.20';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.1';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.7';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.12';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.1';
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.4';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.1'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version4511: spec [
	<version: '4.5.11' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'ThierryGoubier'.
		spec timestamp: '6/18/2014 16:42'.
		spec project: 'Pipeability' with: [ spec version: '4.6.8' ].
		spec 
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.11';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.43';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.2';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.11';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.19';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.2';
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.8';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.2'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version4512: spec [
	<version: '4.5.12' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'ThierryGoubier'.
		spec timestamp: '6/18/2014 16:42'.
		spec project: 'Pipeability' with: [ spec version: '4.6.9' ].
		spec 
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.11';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.45';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.2';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.11';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.20';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.2';
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.8';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.2'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version4513: spec [
	<version: '4.5.13' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'ThierryGoubier'.
		spec timestamp: '6/18/2014 16:42'.
		spec project: 'Pipeability' with: [ spec version: '4.6.9' ].
		spec 
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.11';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.45';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.2';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.12';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.20';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.2';
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.8';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.2'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version457: spec [
	<version: '4.5.7' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'ThierryGoubier'.
		spec timestamp: '9/23/2013 10:36'.
		spec project: 'Pipeability' with: [ spec version: '4.6.7' ].
		spec 
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.11';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.37';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.2';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.9';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.17';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.2';
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.8';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.2'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version458: spec [
	<version: '4.5.8' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'ThierryGoubier'.
		spec timestamp: '9/23/2013 10:36'.
		spec project: 'Pipeability' with: [ spec version: '4.6.7' ].
		spec 
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.11';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.39';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.2';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.9';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.17';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.2';
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.8';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.2'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version45: spec [
	<version: '4.5' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'StephaneDucasse'.
		spec timestamp: '10/02/2013 12:57'.
		spec project: 'Pipeability' with: [ spec version: '1.1' ].
		spec 
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.10';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.27';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.2';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.9';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.15';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.2';
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.5';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.2'. ].

]

{ #category : #versions }
ConfigurationOfOSProcess >> version462: spec [
	<version: '4.6.2' imports: #('4.4.6-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'release'.
		spec description: 'Update to latest package versions'.
		spec author: 'ThierryGoubier'.
		spec timestamp: '6/18/2014 16:42'.
		spec project: 'Pipeability' with: [ spec version: '4.6.12' ].
		spec 
			package: 'OSProcess-AIO' with: 'OSProcess-AIO-dtl.8';
			package: 'OSProcess-Base' with: 'OSProcess-Base-dtl.49';
			package: 'OSProcess-Mac' with: 'OSProcess-Mac-dtl.2';
			package: 'OSProcess-OS2' with: 'OSProcess-OS2-dtl.2';
			package: 'OSProcess-RiscOS' with: 'OSProcess-RiscOS-dtl.2';
			package: 'OSProcess-Tests' with: 'OSProcess-Tests-dtl.13';
			package: 'OSProcess-Unix' with: 'OSProcess-Unix-dtl.23';
			package: 'OSProcess-Win32' with: 'OSProcess-Win32-dtl.14'. ].

]
