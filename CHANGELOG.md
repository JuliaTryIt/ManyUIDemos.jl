# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Wake the CImGui backend again. `demos/_optional_cimgui.jl` imported
  CImGui, GLFW and ModernGL, but `ManyUICImGuiCImGuiExt` is triggered by
  `["CImGui", "GLFW", "HarfBuzz", "ModernGL"]` and an extension fires
  only when EVERY trigger is loaded. Three of four left the extension
  asleep while `HAS_CIMGUI` still reported success, so a `cimgui` mode
  reached the stub and threw "native support requires CImGui, GLFW,
  HarfBuzz and ModernGL" from an environment that had them. HarfBuzz is
  now imported, and `HAS_CIMGUI` asks `native_available()` rather than
  trusting that the imports were enough -- a trigger that fails to
  precompile leaves the extension unloaded too.
- Add HarfBuzz and a `[sources]` block to `CImGuiEnv`, so that
  environment declares the whole trigger set and resolves the
  unregistered siblings from a fresh clone.
- **The CImGui modes launch.** `CImGuiEnv`'s manifest pinned the
  pre-fix commit of the HarfBuzz.jl fork, so it kept re-resolving to
  GLFW_jll 3.3.9 -- the version whose missing `glfwGetPlatform` makes
  libcimgui segfault -- long after the fork fixed its `HarfBuzz_jll`
  bound. Updating the environment resolves to GLFW_jll 3.4.1 /
  HarfBuzz_jll 8.5.1 / Pango_jll 1.58.0, `native_available()` is true,
  and the window opens. `upstream-bugs.md` entry 2 is now a
  regression note rather than a blocker.
- A `cimgui`/`cimguitui` HUB backend in an environment without the GPU
  stack took the process down with an `ArgumentError` and a stacktrace
  from the `ManyUICImGui` stub. It now prints what is missing and the
  command that works, then returns.
- The hub's **Launch** and **Quit** buttons do something in a CImGui
  window. They `quit!` the hub App so the demo can take the screen, but
  the ImGui render loop kept the window up regardless (fixed in
  ManyUICImGui), and the native path has no App to quit at all -- the
  buttons now also call `ManyUICImGui.request_close!()`, a no-op under
  every other backend.
- `_ensure_cimgui_deps!` imported the four extension triggers into
  `HubApp`, a module of ManyUIDemos -- where they are WEAK dependencies,
  so every import threw `Package ManyUIDemos does not have CImGui in its
  dependencies` into a bare `catch`. It reported success from an
  environment that had all four installed while the extension stayed
  asleep. It now imports into `Main`, which resolves against the active
  project.
- Include the Tachikoma demo extension sources in repository checkouts and CI.
- Open the default browser automatically when launching a Web/WebTUI demo from
  the hub; set `MANYUI_NO_BROWSER=1` to disable this in headless environments.

### Added

- `just hub-cimgui [backend]`, `just demo-cimgui [demo] [mode]` and
  `just instantiate-cimgui`: the CImGui modes need `--project=CImGuiEnv`,
  and every existing recipe hardcoded `--project=@.`, where the GPU
  stack is a weak dependency. Asking for a CImGui mode there could only
  ever report it missing -- which is what it did.
- `CImGuiEnv` now depends on `ManyUIDemos` itself, so the hub -- not
  just a single demo file -- runs from the environment where the CImGui
  backend exists.
