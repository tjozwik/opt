module Opt
  module Solvers
    class GurobiSolver < AbstractSolver
      INFINITY = 1e100
      ENVIRONMENT_MUTEX = Mutex.new
      STATUSES = {
        1 => :loaded,
        2 => :optimal,
        3 => :infeasible,
        4 => :unbounded_or_infeasible,
        5 => :unbounded,
        6 => :cutoff,
        7 => :iteration_limit,
        8 => :node_limit,
        9 => :time_limit,
        10 => :solution_limit,
        11 => :interrupted,
        12 => :numeric,
        13 => :suboptimal,
        14 => :in_progress,
        15 => :user_objective_limit,
        16 => :work_limit,
        17 => :memory_limit,
        18 => :locally_optimal,
        19 => :locally_infeasible
      }.freeze

      def solve(sense:, start:, index:, value:, col_lower:, col_upper:, obj:, row_lower:, row_upper:, vars:, offset:, verbose:, type:, time_limit:, indexed_objective:, **)
        api = self.class.native
        env = nil
        model = nil
        env_buffer = [0].pack("J")
        model_buffer = [0].pack("J")

        begin
          # Gurobi environments are per solve; initialization is not thread-safe.
          ENVIRONMENT_MUTEX.synchronize do
            code = api.GRBemptyenv(env_buffer)
            env = Fiddle::Pointer.new(env_buffer.unpack1("J"))
            check(api, code, env)
            check(api, api.GRBsetintparam(env, "OutputFlag", verbose ? 1 : 0), env)
            check(api, api.GRBstartenv(env), env)
          end

          # Keep the existing convex QP contract.
          check(api, api.GRBsetintparam(env, "NonConvex", 0), env) if type == :qp
          # Distinguish infeasibility from unboundedness for continuous models.
          # Keep MIP presolve defaults so unbounded integer variables are detected.
          check(api, api.GRBsetintparam(env, "DualReductions", 0), env) unless type == :mip
          check(api, api.GRBsetdblparam(env, "TimeLimit", time_limit), env) if time_limit

          row_sense = String.new
          rhs = []
          row_lower.zip(row_upper) do |lower, upper|
            if lower == upper
              row_sense << "="
              rhs << lower
            elsif lower == -Float::INFINITY
              row_sense << "<"
              rhs << upper
            else
              row_sense << ">"
              rhs << lower
            end
          end

          code = api.GRBloadmodel(
            env, model_buffer, "opt", vars.size, rhs.size,
            sense == :maximize ? -1 : 1, offset,
            obj.pack("d*"), row_sense, rhs.pack("d*"),
            start[0...-1].pack("i!*"), start.each_cons(2).map { |a, b| b - a }.pack("i!*"),
            index.pack("i!*"), value.pack("d*"),
            bounds(col_lower), bounds(col_upper), vars.map { |v| variable_type(v) }.join,
            nil, nil
          )
          model = Fiddle::Pointer.new(model_buffer.unpack1("J"))
          check(api, code, env)
          model_env = api.GRBgetenv(model)

          if type == :qp
            positions = vars.each_with_index.to_h
            qrow = []
            qcol = []
            qvalue = []
            indexed_objective.each do |key, coefficient|
              next unless key.is_a?(Array) && coefficient != 0

              i, j = key.map { |v| positions.fetch(v) }
              # Problem supplies both orientations; Gurobi sums duplicates.
              next if i > j

              qrow << i
              qcol << j
              qvalue << coefficient
            end
            unless qvalue.empty?
              check(api, api.GRBaddqpterms(model, qvalue.size, qrow.pack("i!*"), qcol.pack("i!*"), qvalue.pack("d*")), model_env)
            end
          end

          check(api, api.GRBoptimize(model), model_env)
          status_buffer = [0].pack("i!")
          check(api, api.GRBgetintattr(model, "Status", status_buffer), model_env)
          status = STATUSES.fetch(status_buffer.unpack1("i!"), :unknown)
          return {status: status} unless status == :optimal

          objective_buffer = [0.0].pack("d")
          solution_buffer = "\0" * (vars.size * Fiddle::SIZEOF_DOUBLE)
          check(api, api.GRBgetdblattr(model, "ObjVal", objective_buffer), model_env)
          check(api, api.GRBgetdblattrarray(model, "X", 0, vars.size, solution_buffer), model_env)
          {status: status, objective: objective_buffer.unpack1("d"), x: solution_buffer.unpack("d*")}
        ensure
          api.GRBfreemodel(model) if model && !model.null?
          api.GRBfreeenv(env) if env && !env.null?
        end
      end

      def self.available?
        native
        true
      rescue LoadError
        false
      end

      def self.native
        ENVIRONMENT_MUTEX.synchronize do
          @native ||= begin
            require_relative "gurobi/native"
            Gurobi::Native.load
          end
        end
      end

      def self.supported_types
        [:lp, :qp, :mip]
      end

      def self.supports_semi_continuous_variables?
        true
      end

      def self.supports_semi_integer_variables?
        true
      end

      private

      def bounds(values)
        values.map { |v| v == Float::INFINITY ? INFINITY : (v == -Float::INFINITY ? -INFINITY : v) }.pack("d*")
      end

      def variable_type(var)
        case var
        when Binary then "B"
        when SemiInteger then "N"
        when SemiContinuous then "S"
        when Integer then "I"
        else "C"
        end
      end

      def check(api, code, env)
        return if code == 0
        raise Error, "Non-convex problem" if code == 10020

        message = env && !env.null? ? api.GRBgeterrormsg(env).to_s : "Could not create environment"
        raise Error, "Gurobi error #{code}: #{message}"
      end
    end
  end
end
