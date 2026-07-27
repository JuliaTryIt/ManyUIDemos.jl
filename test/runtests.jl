using TestItemRunner

@testitem "Aqua.jl" begin
    import Aqua
    import ManyUIDemos
    Aqua.test_all(ManyUIDemos)
end

@run_package_tests
