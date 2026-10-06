# shared test setup

require "minitest/autorun"
require "minitest/pride"
require "rubocop_spinel"

# runs one Spinel cop, configured from config/default.yml, over a snippet
class CopTest < Minitest::Test
  private

  def messages(source)
    processed_source = RuboCop::ProcessedSource.new(source, 3.3, "test.rb")
    team = RuboCop::Cop::Team.new([cop_class.new(config)], config, raise_error: true)
    team.investigate(processed_source).offenses.map(&:message)
  end

  def config
    @config ||= RuboCop::Config.new(
      YAML.load_file(File.expand_path("../config/default.yml", __dir__)).merge("AllCops" => {"TargetRubyVersion" => 3.3})
    )
  end

  # overrides settings of the cop under test, eg. `configure("AllowedRequires" => ["yaml"])`
  def configure(settings)
    name = cop_class.cop_name
    @config = RuboCop::Config.new(config.to_h.merge(name => config.for_cop(name).merge(settings)))
  end
end
