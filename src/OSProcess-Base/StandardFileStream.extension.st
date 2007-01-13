Extension { #name : #StandardFileStream }

{ #category : #'*OSProcess-base' }
StandardFileStream >> fileID [
	"Access method added to support OSProcess -dtl.
	Note that the contents of fileID can and will change after calling this
	method, so the caller should copy the result rather than depending on
	the result to be immutable."

	^ fileID
]
