require "rails_helper"

RSpec.describe ActiveSupport::Inflector, ".pluralize" do
  it "pluralizes regular French nouns with our French rules, and leaves English alone" do
    expect(%w[usager prix nez gaz bureau tuyau jeu journal].map { it.pluralize(:fr) })
      .to eq(%w[usagers prix nez gaz bureaux tuyaux jeux journaux])
    expect("activity".pluralize).to eq("activities")
  end

  it "is what the view helper uses, since the app speaks French" do
    expect(ApplicationController.helpers.pluralize(3, "usager")).to eq("3 usagers")
  end
end
