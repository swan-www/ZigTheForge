# ZigTheForge

\[Targeting Zig v0.12\]

This repo aims to get the `01_Transformations` example of `TheForge` building using Zig as the build system, targeting `msvc` and building on windows. It provides build utilities that can be reused for other projects.


- After cloning, run the command `git submodule update --init --recursive` to clone the submodules (TheForge-ZigMod)
- Navigate to `proj\demo\transformations_01` and run `zig build -Dtarget=x86_64-windows-msvc` to build the `01_Transformations` demo that ships with TheForge.
- Project should compile, including the relevant shaders.
- Run the executable under `proj\demo\transformations_01\zig-out\bin`

`proj\demo\transformations_01\build.zig` shows how the build utilities and `build.zig.zon` can be used to build a project that uses TheForge.
