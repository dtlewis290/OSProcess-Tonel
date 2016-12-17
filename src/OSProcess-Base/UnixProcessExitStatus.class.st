"
A UnixProcessExitStatus represents the exit status of a unix process. This is an integer bit field answered by the wait() system call that contains information about exit status of the process. The meaning of the bit field varies according to the cause of process exit. 

Following a normal process exit, the status may be decoded to provide a small positive integer value in the range 0 - 255, which is the value that is presented by a unix shell as the exit status of a program. If terminated by a signal, the corresponding value is the signal number of the signal that caused process exit.

UnixExitStatus decodes the process exit status in a manner compatible with a typical GNU unix implementation. It is not guaranteed to be portable and may produce misleading results on other unix systems.

"
Class {
	#name : #UnixProcessExitStatus,
	#superclass : #Object,
	#instVars : [
		'intValue'
	],
	#category : 'OSProcess-Unix'
}

{ #category : #'instance creation' }
UnixProcessExitStatus class >> for: integerValue [

	^self new for: integerValue

]

{ #category : #accessing }
UnixProcessExitStatus >> exitStatus [
	self isExited ifTrue: [^self statusIfExited].
	self isSignaled ifTrue: [^self statusIfSignaled].
	self isStopped ifTrue: [^self statusIfStopped].
	self notify: 'cannot decode exit status ', intValue asString.
	^intValue
]

{ #category : #'initialize-release' }
UnixProcessExitStatus >> for: anInteger [
	intValue := anInteger
]

{ #category : #testing }
UnixProcessExitStatus >> isExited [
	"
	/* Nonzero if STATUS indicates normal termination.  */
	#define __WIFEXITED(status)     (__WTERMSIG(status) == 0)
	"
	^ self statusIfSignaled = 0


]

{ #category : #testing }
UnixProcessExitStatus >> isSignaled [
	"
	/* Nonzero if STATUS indicates termination by a signal.  */
	#define __WIFSIGNALED(status) \
	  (((signed char) (((status) & 0x7f) + 1) >> 1) > 0)
	"
	^(((intValue bitAnd: 16r7F) + 1) >> 1) > 0


]

{ #category : #testing }
UnixProcessExitStatus >> isStopped [
	"
	/* Nonzero if STATUS indicates the child is stopped.  */
	#define __WIFSTOPPED(status)    (((status) & 0xff) == 0x7f)
	"
	^(intValue bitAnd: 16rFF) = 16r7F


]

{ #category : #testing }
UnixProcessExitStatus >> isSuccess [
	^self exitStatus = 0
]

{ #category : #printing }
UnixProcessExitStatus >> printOn: aStream [

	self isExited
		ifTrue: [aStream nextPutAll: 'normal termination with status ';
				 nextPutAll: self statusIfExited asString].
	self isSignaled
		ifTrue: [aStream nextPutAll: 'exit due to signal ';
				nextPutAll: self statusIfSignaled asString].
	self isStopped
		ifTrue: [aStream nextPutAll: 'stopped due to signal ';
				nextPutAll: self statusIfStopped].
]

{ #category : #accessing }
UnixProcessExitStatus >> statusIfExited [
	"
	/* If WIFEXITED(STATUS), the low-order 8 bits of the status.  */
	#define __WEXITSTATUS(status)   (((status) & 0xff00) >> 8)
	"
	^(intValue bitAnd: 16rFF00) >> 8
]

{ #category : #accessing }
UnixProcessExitStatus >> statusIfSignaled [
	"
	/* If WIFSIGNALED(STATUS), the terminating signal.  */
	#define __WTERMSIG(status)      ((status) & 0x7f)
	"
	^intValue bitAnd: 16r7F
]

{ #category : #accessing }
UnixProcessExitStatus >> statusIfStopped [
	"
	/* If WIFSTOPPED(STATUS), the signal that stopped the child.  */
	#define __WSTOPSIG(status)      __WEXITSTATUS(status)
	"
	^self statusIfExited
]

{ #category : #accessing }
UnixProcessExitStatus >> value [
	^intValue
]
