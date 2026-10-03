# Opt

:fire: Convex optimization for Ruby

Supports Cbc, Clp, GLOP, GLPK, Gurobi, HiGHS, OSQP, and SCS

[![Build Status](https://github.com/ankane/opt/actions/workflows/build.yml/badge.svg)](https://github.com/ankane/opt/actions)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "opt-rb"
```

And install one or more solvers based on your problem types:

Solver | LP | QP | MIP | License
--- | --- | --- | --- | ---
[Cbc](https://github.com/ankane/cbc-ruby) | ✓ | | ✓ | EPL-2.0
[Clp](https://github.com/ankane/clp-ruby) | ✓ | | | EPL-2.0
[GLOP](https://github.com/ankane/or-tools-ruby) | ✓ | | | Apache-2.0
[GLPK](https://github.com/ankane/glpk-ruby) | ✓ | | ✓ | GPL-3.0-or-later
[Gurobi](https://www.gurobi.com/) | ✓ | ✓ | ✓ | Proprietary
[HiGHS](https://github.com/ankane/highs-ruby) | ✓ | ✓ | ✓ | MIT
[OSQP](https://github.com/ankane/osqp-ruby) | ✓ | ✓ | | Apache-2.0
[SCS](https://github.com/ankane/scs-ruby) | ✓ | ✓ | | MIT

### Gurobi

Install Gurobi Optimizer and configure a valid license. The adapter uses Gurobi's
[C API](https://docs.gurobi.com/projects/optimizer/en/current/reference/c.html)
through Fiddle, without a separate Gurobi Ruby binding. Add Fiddle to your Gemfile
(required on Ruby 4.0 and later):

```ruby
gem "fiddle", require: false
```

Set `GUROBI_HOME` to the platform directory of your installation, for example:

```sh
export GUROBI_HOME=/opt/gurobi1303/linux64
```

Alternatively, set `GUROBI_LIBRARY` to the full path of the Gurobi shared library
(`.so`, `.dylib`, or `.dll`). It takes precedence over `GUROBI_HOME`. Libraries on
the system library search path are also detected. Set these variables before the
first solver lookup. `Opt.available_solvers` checks library availability; a valid
license is required when solving.

```ruby
prob.solve(solver: :gurobi)
```

Gurobi supports LP, convex QP, and linear MIP through this adapter, including
semi-continuous and semi-integer variables. Logging and time limits use the same
`verbose:` and `time_limit:` options as other solvers. As with other adapters,
variable values and the objective are returned only for an optimal solution.

## Getting Started

Create and solve a problem

```ruby
x1 = Opt::Variable.new(0.., "x1")
x2 = Opt::Variable.new(0.., "x2")

prob = Opt::Problem.new
prob.add(2 * x1 + 2 * x2 >= 7)
prob.add(3 * x1 + 4 * x2 >= 12)
prob.add(2 * x1 + x2 >= 6)
prob.minimize(8 * x1 + 10 * x2)
prob.solve
```

Get the value of a variable

```ruby
x1.value
```

QP

```ruby
prob.minimize(x1 * x1)
```

MIP

```ruby
x1 = Opt::Integer.new(0.., "x1")
x2 = Opt::Binary.new("x2")
```

MIP with semi-continuous variables - *HiGHS and Gurobi*

```ruby
x1 = Opt::SemiContinuous.new(2.., "x1")
x2 = Opt::SemiInteger.new(2.., "x2")
```

## Reference

Specify the solver

```ruby
prob.solve(solver: :cbc)
```

Enable verbose logging

```ruby
prob.solve(verbose: true)
```

Set the time limit in seconds

```ruby
prob.solve(time_limit: 30)
```

## Credits

This project was inspired by [CVXPY](https://github.com/cvxpy/cvxpy) and [OR-Tools](https://github.com/google/or-tools).

## History

View the [changelog](CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/opt/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/opt/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/ankane/opt.git
cd opt
bundle install
bundle exec rake test
```

With Gurobi installed and licensed, run its tests separately:

```sh
bundle exec rake test:gurobi
```

The default test task does not require a Gurobi installation or license.
