using TestItemRunner

@testitem "Aqua.jl" begin
    import Aqua
    import ManyUIDemos
    Aqua.test_all(ManyUIDemos)
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
