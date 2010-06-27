Extension { #name : #StandardFileStream }

{ #category : #'*OSProcess' }
StandardFileStream >> atEndOfFile [
	"Answer whether the receiver is at its end based on the result of
	the last read operation. This uses feof() to test the underlying file
	stream status, and can be used as an alternative to #atEnd, which
	does not properly report end of file status for an OSPipe."

	^ fileID isNil or: [OSProcess accessor isAtEndOfFile: fileID]

]

{ #category : #'*OSProcess' }
StandardFileStream >> fileID [
	"The contents of fileID can and will change after calling this method.
	The sender should copy the result rather than depending on the result
	to be immutable."

	^ fileID
]

{ #category : #'*OSProcess' }
StandardFileStream >> isPipe [

	^ false

]
