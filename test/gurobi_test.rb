require_relative "test_helper"
require "open3"
require "tmpdir"
require "fileutils"

class GurobiTest < Minitest::Test
  def setup
    skip unless solver == :gurobi
    super
  end

  def test_quadratic_interior_solution
    x = Opt::Variable.new(-10..10, "x")
    y = Opt::Variable.new(-10..10, "y")
    problem = Opt::Problem.new
    problem.minimize(2 * x * x + 2 * y * x + 3 * y * y - 8 * x - 14 * y + 11)

    result = problem.solve(solver: :gurobi)

    assert_equal :optimal, result[:status]
    assert_in_delta(-7, result[:objective])
    assert_in_delta 1, x.value
    assert_in_delta 2, y.value
    assert_in_delta problem.objective.value, result[:objective]
  end

  def test_time_limit_without_solution
    x = Opt::Integer.new(0..10, "x")
    problem = Opt::Problem.new
    problem.maximize(x)

    assert_equal({status: :time_limit}, problem.solve(time_limit: 0))
    assert_nil x.value
  end

  def test_invalid_parameter_and_recovery
    x = Opt::Variable.new(0..10, "x")
    problem = Opt::Problem.new
    problem.maximize(x)

    error = assert_raises(Opt::Error) { problem.solve(time_limit: -1) }
    assert_match(/Gurobi error .*TimeLimit/, error.message)
    assert_equal :optimal, problem.solve[:status]
    assert_in_delta 10, x.value
  end

  def test_semi_continuous_active_lower_bound
    x = Opt::SemiContinuous.new(2..4, "x")
    problem = Opt::Problem.new
    problem.add(x >= 0.5)
    problem.minimize(x)

    assert_equal :optimal, problem.solve[:status]
    assert_in_delta 2, x.value
  end

  def test_semi_integer_active_lower_bound
    x = Opt::SemiInteger.new(2.2..6, "x")
    problem = Opt::Problem.new
    problem.add(x >= 0.5)
    problem.minimize(x)

    assert_equal :optimal, problem.solve[:status]
    assert_equal 3, x.value
  end

  def test_exclusive_integer_bound
    x = Opt::Integer.new(0...4, "x")
    problem = Opt::Problem.new
    problem.maximize(x)

    assert_equal :optimal, problem.solve[:status]
    assert_equal 3, x.value
  end

  def test_verbose
    x = Opt::Variable.new(0..1, "x")
    problem = Opt::Problem.new
    problem.maximize(x)

    out, err = capture_subprocess_io { problem.solve }
    assert_empty out
    assert_empty err

    out, = capture_subprocess_io { problem.solve(verbose: true) }
    assert_match(/Optimal objective/, out)
  end

  def test_license_error
    script = <<~RUBY
      require "opt"
      abort "Library should be available without a license" unless Opt.available_solvers.include?(:gurobi)
      x = Opt::Variable.new(0..1)
      problem = Opt::Problem.new
      problem.minimize(x)
      begin
        problem.solve(solver: :gurobi)
        abort "Expected license error"
      rescue Opt::Error => e
        abort e.message unless e.message.include?("Gurobi error 10009")
      end
    RUBY
    out, err, status = Open3.capture3(
      {"GRB_LICENSE_FILE" => File.expand_path("missing-gurobi-license", __dir__)},
      RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", script
    )
    assert status.success?, out + err
  end
end

class GurobiLoadingTest < Minitest::Test
  def test_unavailable_library_does_not_break_opt
    script = <<~RUBY
      require "opt"
      abort "Unexpected Gurobi availability" if Opt.available_solvers.include?(:gurobi)
      begin
        Opt::Solvers::GurobiSolver.native
        abort "Expected LoadError"
      rescue LoadError => e
        abort e.message unless e.message.include?("GUROBI_LIBRARY")
      end
    RUBY
    out, err, status = Open3.capture3(
      {"GUROBI_LIBRARY" => File.expand_path("missing-gurobi-library", __dir__)},
      RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", script
    )
    assert status.success?, out + err
  end

  def test_home_excludes_internal_libraries
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, "lib"))
      FileUtils.touch(File.join(home, "lib", "libgurobi130_light.so"))
      FileUtils.touch(File.join(home, "lib", "libgurobi130.so"))
      script = <<~RUBY
        require "opt"
        require "opt/solvers/gurobi/native"
        paths = Opt::Solvers::Gurobi::Native.library_paths
        abort paths.inspect unless paths.first == File.join(ENV.fetch("GUROBI_HOME"), "lib", "libgurobi130.so")
        abort paths.inspect if paths.any? { |path| path.include?("_light") }
      RUBY
      out, err, status = Open3.capture3(
        {"GUROBI_HOME" => home, "GUROBI_LIBRARY" => nil},
        RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", script
      )
      assert status.success?, out + err
    end
  end
end
