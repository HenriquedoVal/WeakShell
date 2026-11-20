release: mlopt := -DNDEBUG

debug: mlopt := -Zi
debug: linkopt := /DEBUG

debug: wksh.exe tests.exe
release: wksh.exe

language.obj: language.asm language.inc common.inc
	ml64 -nologo -c -quiet -W3 $(mlopt) language.asm

execution.obj: execution.asm execution.inc language.inc common.inc
	ml64 -nologo -c -quiet -W3 $(mlopt) execution.asm

main.obj: main.asm language.inc execution.inc common.inc
	ml64 -nologo -c -quiet -W3 $(mlopt) main.asm

tests.obj: tests.asm language.inc common.inc
	ml64 -nologo -c -quiet -W3 $(mlopt) tests.asm

tests.exe: tests.obj language.obj
	link -nologo -out:tests.exe -entry:main $(linkopt) tests.obj language.obj

wksh.exe: main.obj language.obj execution.obj
	link -nologo -out:wksh.exe -entry:main $(linkopt) main.obj language.obj execution.obj

clean:
	del /s /q *.obj *.exe *.ilk *.pdb
