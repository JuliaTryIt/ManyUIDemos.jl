using TestItemRunner

@testitem "Aqua.jl" begin
    import Aqua
    import ManyUIDemos
    # DefaultApplication, HarfBuzz and Tachikoma are imported through
    # `@eval import` at the point a backend is chosen (see hub.jl), so
    # Aqua's static scan cannot see them and calls them stale. They are
    # declared on purpose: dropping one turns a launch mode into an
    # UndefVarError.
    Aqua.test_all(ManyUIDemos;
                  stale_deps = (; ignore = [:DefaultApplication,
                                            :HarfBuzz, :Tachikoma]))
end

@testitem "Demos Compile" begin
    demos_dir = joinpath(pkgdir(ManyUIDemos), "demos")
    for file in readdir(demos_dir)
        if endswith(file, ".jl")
            # Including the file will compile its definitions and throw if there's a syntax error
            # We don't run the `main()` function because `abspath(PROGRAM_FILE)` is not `@__FILE__` during tests.
            demo_module = Module(Symbol("DemoCompile_", replace(file, ".jl" => "")))
            @test_nowarn Base.include(demo_module, joinpath(demos_dir, file))
        end
    end
end

@run_package_tests
