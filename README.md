# OSProcess

OSProcess provides access to operating system functions, including pipes, child process creation, and control of the Squeak VM process.

See:
- http://www.squeaksource.com/OSProcess.html
- http://wiki.squeak.org/squeak/1914

To load (the in-development version) in Pharo 7 and later:

```smalltalk
Metacello new
	repository: 'github://akgrant43/OSProcess:akgmerge/src';
	baseline: 'OSProcess';
	load.
```
