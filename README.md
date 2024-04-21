# ZigTheForge

- After cloning, run the command `git submodule update --init --recursive` to clone the submodules (TheForge-ZigMod)
- Navigate to `proj\demo\transformations_01` and run `zig build -Dtarget=x86_64-windows-msvc` to build the `01_Transformations` demo that ships with TheForge.
- Project should compile, including the relevant shaders.
- Run the executable under `proj\demo\transformations_01\zig-out\bin`

`proj\demo\transformations_01\build.zig` shows how the build utilities and `build.zig.zon` can be used to build a project that uses TheForge.
