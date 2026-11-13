require "rails_helper"

RSpec.describe UsagerImports::UsagerIndex do
  let(:index) do
    [
      { "id" => 11, "first_name" => "Grace", "last_name" => "Hopper", "email" => "Grace@Example.fr" },
      { "id" => 12, "first_name" => "Alan", "last_name" => "Turing", "phone_number" => "0612345678" },
      { "id" => 13, "first_name" => "Hélène", "last_name" => "Dupont" },
    ].each_with_object(described_class.new) { |usager, index| index.add_usager(usager) }
  end

  def person(first_name, last_name, email: nil, phone: nil)
    Pipedrive::Beneficiaries::Person.new(id: "1", first_name:, last_name:, email:, phone:)
  end

  it "gives the usager with the same e-mail or phone, not one with only the same name" do
    expect(index.usager_id(person("G", "H", email: "grace@example.fr"))).to eq(11)
    expect(index.usager_id(person("A", "T", phone: "+33 6 12 34 56 78"))).to eq(12)
    expect(index.usager_id(person("helene", "DUPONT"))).to be_nil
    expect(index).to include(person("helene", "DUPONT"))
  end

  it "has no usager id for a person added to it" do
    index.add_person(person("Ada", "Lovelace", email: "ada@example.fr"))

    expect(index).to include(person("A", "L", email: "ada@example.fr"))
    expect(index.usager_id(person("A", "L", email: "ada@example.fr"))).to be_nil
  end
end
