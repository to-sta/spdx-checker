Build command

Windows CLI command
zig build-lib -lc -dynamic -I "C:\Users\tobia\AppData\Local\Programs\Python\Python313\include" -L "C:\Users\tobia\AppData\Local\Programs\Python\Python313\libs" -l "python3" simple.zig

File name needs to be changed:
* simple.dll.obj
* simple.dll -> simple.pyd

WSL Ubuntu CLI command
zig build-lib -lc -dynamic -I "/usr/include/python3.12" -L "/usr/lib/x86_6
4-linux-gnu/" -l "python3.12" simple.zig

File name needs to be changed:
* libsimple.a -> simple.a
* libsimple.so -> simple.so