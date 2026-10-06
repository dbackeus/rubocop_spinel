# tests for the Spinel unsupported-feature cop

require_relative "test_helper"

class TestUnsupportedCop < CopTest
  def test_flags_string_eval
    assert_equal [
      "Spinel does not support `eval` of a string.",
      "Spinel does not support `class_eval` with a string; use the block form.",
      "Spinel does not support `instance_eval` with a string; use the block form.",
    ], messages(<<~RUBY)
      eval("1")
      Foo.class_eval("def x = 1")
      obj.instance_eval("@x")
    RUBY
  end

  def test_allows_block_evals_and_class_body_macros
    assert_empty messages(<<~RUBY)
      class Foo
        class_eval "def x = 1"
        class_eval { def y = 1 }
      end
      obj.instance_eval { add(1) }
      obj.instance_exec(2) { |n| n }
      def configure(&block)
        log(block)
        instance_eval(&block)
      end
    RUBY
  end

  def test_allows_features_spinel_now_supports
    assert_empty messages(<<~RUBY)
      Thread.new { Mutex.new.synchronize { 1 } }
      target.send(name)
      target.public_send(:size)
      Foo.const_get(name)
      "x".prepend("y")
      class Person
        prepend Loud
        extend Greeter
        define_singleton_method(:build) { new }
        class << self
          def greet = "hi"
        end
      end
      module Helpers
        extend self
        def count = 1
        module_function :count
      end
    RUBY
  end

  def test_skips_code_ruled_out_by_ruby_engine
    assert_empty messages(<<~RUBY)
      if RUBY_ENGINE == "spinel"
        1
      else
        eval(code)
      end
      unless RUBY_ENGINE == "spinel"
        eval(code)
      end
      RUBY_ENGINE != "spinel" ? binding : nil
      def check(code)
        return :aot if RUBY_ENGINE == "spinel"
        eval(code)
      end
    RUBY
  end

  def test_skips_methods_the_program_defines
    assert_empty messages(<<~RUBY)
      def eval(node) = node
      eval(1)
    RUBY
  end

  def test_flags_runtime_removal
    assert_equal [
      "Spinel does not support `remove_method`.",
      "Spinel does not support `undef_method`.",
      "Spinel does not support `remove_const`.",
      "Spinel does not support `singleton_method`.",
    ], messages(<<~RUBY)
      remove_method :a
      undef_method :a
      Object.send(:remove_const, :X)
      Foo.singleton_method(:a)
    RUBY
  end

  def test_define_method
    assert_empty messages(<<~RUBY)
      class Foo
        define_method(:zero) { 0 }
        define_method(:sq, ->(x) { x * x })
        %i[a b].each { |n| define_method(n) { n } }
        [1, 2].each { |n| define_method("value_\#{n}") { n } }
      end
    RUBY
    assert_equal [
      "Spinel only supports `define_method` with a literal name in a class body.",
      "Spinel only supports `define_method` with a literal name in a class body.",
      "Spinel only supports `define_method` with a literal name in a class body.",
      "Spinel only supports `define_method` in the class body, not on a receiver.",
    ], messages(<<~RUBY)
      class Foo
        define_method(name) { 0 }
        FIELDS.each { |f| define_method(f) { f } }
        def setup = define_method(:x) { 1 }
      end
      Foo.define_method(:hi) { 1 }
    RUBY
  end

  def test_allows_singleton_methods_on_traceable_receivers
    assert_empty messages(<<~RUBY)
      o = Point.new
      def o.hi = 1
      o.extend(Greeter)
      class << o
        def bye = 2
      end
      OBJ = Point.new
      OBJ.define_singleton_method(:x) { 1 }
      def Point.origin = new
      module Concern
        def self.included(base)
          base.extend(ClassMethods)
          base.include(Helpers)
        end
      end
    RUBY
  end

  def test_flags_singleton_methods_on_untraceable_receivers
    assert_equal [
      "Spinel only supports singleton methods on self in a class body, or on a class or an object assigned `Klass.new`.",
      "Spinel only supports `extend` in a class body, or on an object assigned `Klass.new`.",
      "Spinel only supports `class << self` in a class body, or on a class or an object assigned `Klass.new`.",
      "Spinel only supports `extend` in a class body, or on an object assigned `Klass.new`.",
      "Spinel only supports `define_singleton_method` in a class body, or on an object assigned `Klass.new`.",
      "Spinel only supports `extend self` in a module.",
    ], messages(<<~RUBY)
      o = Object.new
      def o.hi = 1
      build.extend(Greeter)
      class << factory
      end
      Point.extend(Greeter)
      class Point
        def initialize = define_singleton_method(:x) { 1 }
        extend self
      end
    RUBY
  end

  def test_flags_class_structure
    assert_equal [
      "Spinel only supports `include` in the class body, not on a receiver.",
      "Spinel only supports `attr_accessor` in the class body, not on a receiver.",
      "Spinel only supports `include` in the class body, not on a receiver.",
      "Spinel only supports `include` of a constant module.",
      "Spinel only supports a constant superclass.",
      "Spinel does not support subclassing `Array`; wrap it in an instance variable.",
      "Spinel does not support subclassing `Hash`; wrap it in an instance variable.",
      "Spinel does not support a class named `Process`, the builtin module.",
      "Spinel does not support `Struct.new` with a string name; use `Name = Struct.new(...)`.",
    ], messages(<<~RUBY)
      Foo.include(Greeter)
      Foo.attr_accessor :x
      Foo.send(:include, Greeter)
      class D
        include pick(Greeter)
      end
      class A < parent; end
      class Stack < Array; end
      Registry = Class.new(Hash)
      module Jobs
        class Process; end
      end
      Struct.new("Pair", :a, :b)
    RUBY
  end

  def test_allows_static_class_structure
    assert_empty messages(<<~RUBY)
      class A < Struct.new(:a); end
      class B < Data.define(:b); end
      class C < (Base); end
      class D
        singleton_class.include(Greeter)
        singleton_class.attr_accessor :level
      end
      module Shop
        class String; end
        class Fancy < String; end
      end
    RUBY
  end

  def test_flags_reflection
    assert_equal [
      "Spinel only supports `binding.local_variable_get(:name)` and friends.",
      "Spinel does not support `local_variables`.",
      "Spinel only supports `instance_variable_get` with a literal name.",
      "Spinel only supports `instance_variable_set` with a literal name.",
      "Spinel only supports `alias_method` with a literal name.",
      "Spinel only supports `method_defined?` with a literal name.",
      "Spinel does not support `singleton_class` as an object.",
      "Spinel does not support `ObjectSpace` (except `define_finalizer`).",
      "Spinel does not support `ObjectSpace` (except `define_finalizer`).",
      "Spinel does not support `TracePoint`.",
      "Spinel does not support `set_trace_func`.",
    ], messages(<<~RUBY)
      ERB.new(t).result(binding)
      local_variables
      obj.instance_variable_get(name)
      instance_variable_set("@\#{k}", v)
      alias_method name, :a
      Foo.method_defined?(name)
      obj.singleton_class
      ObjectSpace.each_object(Class)
      ObjectSpace::WeakMap.new
      TracePoint.new(:call) {}
      set_trace_func(nil)
    RUBY
    assert_empty messages(<<~RUBY)
      binding.local_variable_get(:x)
      obj.instance_variable_get(:@a)
      ObjectSpace.define_finalizer(obj, pr)
    RUBY
  end

  def test_flags_runtime_features
    assert_equal [
      "Spinel does not support `fork`; use `Process.spawn` or threads.",
      "Spinel does not support `fork`; use `Process.spawn` or threads.",
      "Spinel does not support `load`; use `require_relative`.",
      "Spinel does not support `IO.popen`; use `Open3.capture2` or `Process.spawn`.",
      "Spinel does not support refinements; reopen the class instead.",
      "Spinel does not support refinements; reopen the class instead.",
      "Spinel does not support `callcc`.",
      "Spinel does not support `ruby2_keywords`.",
      "Spinel does not support `compare_by_identity`; key by an explicit id.",
      "Spinel does not support `unicode_normalize`.",
      "Spinel does not support `slice_before` with a Proc; use the block form.",
      "Spinel does not support `DATA` / `__END__`.",
      "Spinel does not support flip-flops; use a boolean variable.",
    ], messages(<<~RUBY)
      fork { 1 }
      Process.fork { 1 }
      load "x.rb"
      IO.popen(["ls"])
      module Shout
        refine(String) { def shout = upcase }
      end
      using Shout
      callcc { |k| k }
      ruby2_keywords def fwd(*args) = target(*args)
      {}.compare_by_identity
      s.unicode_normalize(:nfc)
      list.slice_before(->(x) { x.even? })
      DATA.read
      (1..9).each { |i| p i if (i == 3)..(i == 5) }
    RUBY
  end

  def test_flags_unsupported_requires
    assert_equal ["Spinel does not provide `require \"date\"`."], messages(<<~RUBY)
      require "date"
      require "json"
      require_relative "date"
    RUBY
  end

  private

  def cop_class = RuboCop::Cop::Spinel::Unsupported
end
