require "rails_helper"

RSpec.describe ApplicationHelper do
  it "gives a read-only field with a copy button" do
    field = helper.copy_field("caldav-url", "https://x.example/c/")

    expect(field).to include('id="caldav-url"', 'value="https://x.example/c/"', 'data-copy-target="caldav-url"')
    expect(field).to include("readonly")
  end
end
