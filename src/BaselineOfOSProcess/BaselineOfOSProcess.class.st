Class {
	#name : #BaselineOfOSProcess,
	#superclass : #BaselineOf,
	#category : #BaselineOfOSProcess
}

{ #category : #baselines }
BaselineOfOSProcess >> baseline: spec [

	<baseline>
	spec for: #common do: [ self baselineForCommon: spec ].
	spec for: #'pharo9.x' do: [ self baselineForPharo9: spec ]
]

{ #category : #baselines }
BaselineOfOSProcess >> baselineForCommon: spec [

spec postLoadDoIt: #postload:package:.
		spec baseline: 'CommandShell' with: [ 
			spec
				repository: 'github://dtlewis290/CommandShell-Tonel/src';
				loads: #( 'Piping' ) ].

		spec
			package: 'OSProcess-Base';
			package: 'OSProcess-AIO';
			package: 'OSProcess-Mac';
			package: 'OSProcess-OS2';
			package: 'OSProcess-RiscOS';
			package: 'OSProcess-Tests';
			package: 'OSProcess-Unix';
			package: 'OSProcess-Win32'.

		spec
			group: 'Core'
			with:
				#( 'OSProcess-Base' 'OSProcess-AIO' 'OSProcess-Mac'
				   'OSProcess-Unix' 'OSProcess-Win32' );
			group: 'Core with Output' with: #( 'Core' 'CommandShell' );
			group: 'OS2' with: #( 'Core' 'OSProcess-OS2' );
			group: 'RiscOS' with: #( 'Core' 'OSProcess-RiscOS' );
			group: 'Tests' with: #( 'Core' 'OSProcess-Tests' );
			group: 'default' with: #( 'Tests' )
]

{ #category : #baselines }
BaselineOfOSProcess >> baselineForPharo9: spec [

	spec
		baseline: 'DeprecatedFileStream'
		with: [ 
		spec repository: 'github://luque/DeprecatedFileStream:main/src' ].
	self baselineForCommon: spec
]

{ #category : #actions }
BaselineOfOSProcess >> postload: loader package: packageSpec [

	(Smalltalk at: #ThisOSProcess) startUp: true
]
