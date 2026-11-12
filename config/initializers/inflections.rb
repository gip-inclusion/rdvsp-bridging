# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# French plurals for the views' pluralize (the app speaks French; English inflections stay the default elsewhere).
# Regular rules only: add exceptions (bleu → bleus, bal → bals…) with inflect.irregular when a view needs one.
ActiveSupport::Inflector.inflections(:fr) do |inflect|
  inflect.plural(/$/, "s")
  inflect.plural(/([sxz])$/i, '\1')
  inflect.plural(/(eau|au|eu)$/i, '\1x')
  inflect.plural(/al$/i, "aux")
end
