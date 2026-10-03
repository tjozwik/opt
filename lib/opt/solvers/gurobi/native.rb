require "fiddle/import"

module Opt
  module Solvers
    module Gurobi
      module Native
        def self.load
          errors = []
          library_paths.each do |path|
            begin
              api = Module.new
              api.extend(Fiddle::Importer)
              api.dlload(path)
              api.extern "int GRBemptyenv(void**)"
              api.extern "int GRBstartenv(void*)"
              api.extern "void GRBfreeenv(void*)"
              api.extern "int GRBsetintparam(void*, const char*, int)"
              api.extern "int GRBsetdblparam(void*, const char*, double)"
              api.extern "int GRBloadmodel(void*, void**, const char*, int, int, int, double, double*, char*, double*, int*, int*, int*, double*, double*, double*, char*, char**, char**)"
              api.extern "int GRBaddqpterms(void*, int, int*, int*, double*)"
              api.extern "int GRBoptimize(void*)"
              api.extern "int GRBgetintattr(void*, const char*, int*)"
              api.extern "int GRBgetdblattr(void*, const char*, double*)"
              api.extern "int GRBgetdblattrarray(void*, const char*, int, int, double*)"
              api.extern "void* GRBgetenv(void*)"
              api.extern "const char* GRBgeterrormsg(void*)"
              api.extern "void GRBfreemodel(void*)"
              return api
            rescue Fiddle::DLError => e
              errors << e.message
            end
          end
          raise LoadError, "Could not load Gurobi. Set GUROBI_HOME or GUROBI_LIBRARY to your installation. #{errors.first}"
        end

        def self.library_paths
          return [ENV.fetch("GUROBI_LIBRARY")] if ENV["GUROBI_LIBRARY"]

          paths = []
          if ENV["GUROBI_HOME"]
            home = ENV.fetch("GUROBI_HOME")
            patterns = ["lib/libgurobi*.so", "lib/libgurobi*.dylib", "bin/gurobi*.dll"]
            libraries = patterns.flat_map { |pattern| Dir.glob(File.join(home, pattern)) }
            # Exclude internal libraries such as libgurobi130_light.so.
            libraries.select! { |path| File.basename(path).match?(/\A(?:libgurobi\d*\.(?:so|dylib)|gurobi\d+\.dll)\z/) }
            paths.concat(libraries.sort.reverse)
          end
          paths.concat(["libgurobi.so", "libgurobi.dylib"])
          %w[130 120 110 100 95 91 90].each do |version|
            paths.concat(["libgurobi#{version}.so", "libgurobi#{version}.dylib", "gurobi#{version}.dll"])
          end
          paths
        end
      end
    end
  end
end
